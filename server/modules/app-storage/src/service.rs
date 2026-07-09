use std::path::{Path, PathBuf};

use chrono::{DateTime, Datelike, Utc};
use serde::Serialize;
use tokio::fs;
use uuid::Uuid;

use crate::image::process_image;

const MAX_IMAGE_SIZE: usize = 10 * 1024 * 1024;
const MAX_VIDEO_SIZE: usize = 50 * 1024 * 1024;
const MAX_FILE_SIZE: usize = 50 * 1024 * 1024;

#[derive(Debug, Serialize)]
pub struct ImageUploadResponse {
    pub original_url: String,
    pub thumbnail_url: String,
    pub width: u32,
    pub height: u32,
    pub size: usize,
    pub format: String,
}

#[derive(Debug, Serialize)]
pub struct VideoUploadResponse {
    pub video_url: String,
    pub thumbnail_url: String,
    pub duration_ms: i64,
    pub width: u32,
    pub height: u32,
    pub file_size: usize,
}

#[derive(Debug, Serialize)]
pub struct FileUploadResponse {
    pub file_url: String,
    pub file_name: String,
    pub file_size: usize,
    pub file_type: String,
}

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("missing file")]
    MissingFile,
    #[error("unsupported format")]
    UnsupportedFormat,
    #[error("file too large")]
    FileTooLarge,
    #[error("invalid metadata")]
    InvalidMetadata,
    #[error("io error")]
    Io(#[from] std::io::Error),
    #[error("image error")]
    Image(#[from] image::ImageError),
}

#[derive(Clone)]
pub struct AppStorageService {
    root: PathBuf,
}

impl AppStorageService {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    pub async fn upload_image(
        &self,
        bytes: Vec<u8>,
        filename: &str,
    ) -> Result<ImageUploadResponse, StorageError> {
        if bytes.is_empty() {
            return Err(StorageError::MissingFile);
        }
        if bytes.len() > MAX_IMAGE_SIZE {
            return Err(StorageError::FileTooLarge);
        }
        let ext = ensure_allowed_extension(filename, &["jpg", "jpeg", "png", "gif", "webp"])?;

        let now = Utc::now();
        let original_path = dated_path(&self.root, "original", &ext, now);
        let thumb_path = dated_path(&self.root, "thumb", "webp", now);

        let processed = process_image(&bytes)?;
        write_bytes(&original_path, &bytes).await?;
        write_bytes(&thumb_path, &processed.thumb_webp).await?;

        Ok(ImageUploadResponse {
            original_url: public_url(&self.root, &original_path),
            thumbnail_url: public_url(&self.root, &thumb_path),
            width: processed.width,
            height: processed.height,
            size: bytes.len(),
            format: ext,
        })
    }

    pub async fn upload_video(
        &self,
        video: Vec<u8>,
        video_name: &str,
        thumb: Vec<u8>,
        thumb_name: &str,
        duration_ms: i64,
        width: u32,
        height: u32,
    ) -> Result<VideoUploadResponse, StorageError> {
        if video.is_empty() || thumb.is_empty() {
            return Err(StorageError::MissingFile);
        }
        if video.len() > MAX_VIDEO_SIZE || thumb.len() > MAX_IMAGE_SIZE {
            return Err(StorageError::FileTooLarge);
        }
        if duration_ms <= 0 {
            return Err(StorageError::InvalidMetadata);
        }

        let video_ext = ensure_allowed_extension(video_name, &["mp4", "mov", "avi"])?;
        let thumb_ext = ensure_allowed_extension(thumb_name, &["jpg", "jpeg", "png", "webp"])?;

        let now = Utc::now();
        let video_path = dated_path(&self.root, "video", &video_ext, now);
        let thumb_path = dated_path(&self.root, "thumb", &thumb_ext, now);

        write_bytes(&video_path, &video).await?;
        write_bytes(&thumb_path, &thumb).await?;

        Ok(VideoUploadResponse {
            video_url: public_url(&self.root, &video_path),
            thumbnail_url: public_url(&self.root, &thumb_path),
            duration_ms,
            width,
            height,
            file_size: video.len(),
        })
    }

    pub async fn upload_file(
        &self,
        bytes: Vec<u8>,
        filename: &str,
    ) -> Result<FileUploadResponse, StorageError> {
        if bytes.is_empty() {
            return Err(StorageError::MissingFile);
        }
        if bytes.len() > MAX_FILE_SIZE {
            return Err(StorageError::FileTooLarge);
        }
        let ext = extension_or_default(filename);
        let now = Utc::now();
        let file_path = dated_path(&self.root, "file", &ext, now);
        write_bytes(&file_path, &bytes).await?;

        Ok(FileUploadResponse {
            file_url: public_url(&self.root, &file_path),
            file_name: filename.to_string(),
            file_size: bytes.len(),
            file_type: ext,
        })
    }
}

fn ensure_allowed_extension(filename: &str, allowed: &[&str]) -> Result<String, StorageError> {
    let ext = extension_or_default(filename);
    if allowed.iter().any(|allowed_ext| ext == *allowed_ext) {
        return Ok(ext);
    }
    Err(StorageError::UnsupportedFormat)
}

fn extension_or_default(filename: &str) -> String {
    Path::new(filename)
        .extension()
        .and_then(|value| value.to_str())
        .map(|value| value.trim().to_ascii_lowercase())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "bin".to_string())
}

fn dated_path(root: &Path, kind: &str, ext: &str, now: DateTime<Utc>) -> PathBuf {
    root.join(kind)
        .join(format!("{:04}", now.year()))
        .join(format!("{:02}", now.month()))
        .join(format!("{}.{}", Uuid::new_v4(), ext))
}

fn public_url(root: &Path, path: &Path) -> String {
    let relative = path
        .strip_prefix(root)
        .expect("public url path should live under storage root")
        .to_string_lossy()
        .replace('\\', "/");
    format!("/uploads/{relative}")
}

async fn write_bytes(path: &Path, bytes: &[u8]) -> Result<(), std::io::Error> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).await?;
    }
    fs::write(path, bytes).await
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::{AppStorageService, StorageError};

    fn temp_root() -> std::path::PathBuf {
        std::env::temp_dir().join(format!(
            "flash-im-storage-test-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("time should advance")
                .as_nanos()
        ))
    }

    #[tokio::test]
    async fn rejects_unsupported_image_extension() {
        let service = AppStorageService::new(temp_root());

        let error = service
            .upload_image(vec![1, 2, 3], "demo.txt")
            .await
            .expect_err("txt should be rejected");

        assert!(matches!(error, StorageError::UnsupportedFormat));
    }

    #[tokio::test]
    async fn upload_file_returns_uploads_url() {
        let root = temp_root();
        let service = AppStorageService::new(&root);

        let response = service
            .upload_file(b"hello".to_vec(), "report.pdf")
            .await
            .expect("file upload should succeed");

        assert!(response.file_url.starts_with("/uploads/file/"));
        assert_eq!(response.file_type, "pdf");

        let _ = fs::remove_dir_all(root).await;
    }
}
