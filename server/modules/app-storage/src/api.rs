use axum::{Json, Router, extract::Multipart, routing::post};
use flash_core::{AppError, AppResult, SharedContext};

use crate::service::{AppStorageService, StorageError};

pub fn router() -> Router<SharedContext> {
    Router::<SharedContext>::new()
        .route("/api/upload/image", post(upload_image))
        .route("/api/upload/video", post(upload_video))
        .route("/api/upload/file", post(upload_file))
}

async fn upload_image(mut multipart: Multipart) -> AppResult<Json<crate::ImageUploadResponse>> {
    let mut file = None;
    let mut file_name = None;
    let mut content_type = None;

    while let Some(field) = next_field(&mut multipart).await? {
        if field.name() == Some("file") {
            file_name = field.file_name().map(ToOwned::to_owned);
            content_type = field.content_type().map(ToOwned::to_owned);
            file = Some(
                field
                    .bytes()
                    .await
                    .map_err(|_| AppError::bad_request("invalid upload file"))?
                    .to_vec(),
            );
        }
    }

    require_allowed_content_type(
        content_type.as_deref(),
        &["image/jpeg", "image/png", "image/gif", "image/webp"],
    )?;

    let service = AppStorageService::new("uploads");
    let response = service
        .upload_image(
            file.ok_or(AppError::bad_request("missing file"))?,
            file_name
                .as_deref()
                .ok_or(AppError::bad_request("missing file name"))?,
        )
        .await
        .map_err(map_storage_error)?;

    Ok(Json(response))
}

async fn upload_video(mut multipart: Multipart) -> AppResult<Json<crate::VideoUploadResponse>> {
    let mut video = None;
    let mut video_name = None;
    let mut video_content_type = None;
    let mut thumb = None;
    let mut thumb_name = None;
    let mut thumb_content_type = None;
    let mut duration_ms = None;
    let mut width = 0_u32;
    let mut height = 0_u32;

    while let Some(field) = next_field(&mut multipart).await? {
        match field.name() {
            Some("video") => {
                video_name = field.file_name().map(ToOwned::to_owned);
                video_content_type = field.content_type().map(ToOwned::to_owned);
                video = Some(
                    field
                        .bytes()
                        .await
                        .map_err(|_| AppError::bad_request("invalid video file"))?
                        .to_vec(),
                );
            }
            Some("thumbnail") => {
                thumb_name = field.file_name().map(ToOwned::to_owned);
                thumb_content_type = field.content_type().map(ToOwned::to_owned);
                thumb = Some(
                    field
                        .bytes()
                        .await
                        .map_err(|_| AppError::bad_request("invalid thumbnail file"))?
                        .to_vec(),
                );
            }
            Some("duration_ms") => {
                duration_ms = Some(parse_i64_field(field).await?);
            }
            Some("width") => {
                width = parse_u32_field(field).await?;
            }
            Some("height") => {
                height = parse_u32_field(field).await?;
            }
            _ => {}
        }
    }

    require_allowed_content_type(
        video_content_type.as_deref(),
        &["video/mp4", "video/quicktime", "video/x-msvideo"],
    )?;
    require_allowed_content_type(
        thumb_content_type.as_deref(),
        &["image/jpeg", "image/png", "image/webp"],
    )?;

    let service = AppStorageService::new("uploads");
    let response = service
        .upload_video(
            video.ok_or(AppError::bad_request("missing video file"))?,
            video_name
                .as_deref()
                .ok_or(AppError::bad_request("missing video file name"))?,
            thumb.ok_or(AppError::bad_request("missing thumbnail file"))?,
            thumb_name
                .as_deref()
                .ok_or(AppError::bad_request("missing thumbnail file name"))?,
            duration_ms.ok_or(AppError::bad_request("missing duration_ms"))?,
            width,
            height,
        )
        .await
        .map_err(map_storage_error)?;

    Ok(Json(response))
}

async fn upload_file(mut multipart: Multipart) -> AppResult<Json<crate::FileUploadResponse>> {
    let mut file = None;
    let mut file_name = None;

    while let Some(field) = next_field(&mut multipart).await? {
        if field.name() == Some("file") {
            file_name = field.file_name().map(ToOwned::to_owned);
            file = Some(
                field
                    .bytes()
                    .await
                    .map_err(|_| AppError::bad_request("invalid upload file"))?
                    .to_vec(),
            );
        }
    }

    let service = AppStorageService::new("uploads");
    let response = service
        .upload_file(
            file.ok_or(AppError::bad_request("missing file"))?,
            file_name
                .as_deref()
                .ok_or(AppError::bad_request("missing file name"))?,
        )
        .await
        .map_err(map_storage_error)?;

    Ok(Json(response))
}

async fn next_field(
    multipart: &mut Multipart,
) -> AppResult<Option<axum::extract::multipart::Field<'_>>> {
    multipart
        .next_field()
        .await
        .map_err(|_| AppError::bad_request("invalid multipart body"))
}

async fn parse_i64_field(field: axum::extract::multipart::Field<'_>) -> AppResult<i64> {
    field
        .text()
        .await
        .map_err(|_| AppError::bad_request("invalid multipart field"))?
        .parse::<i64>()
        .map_err(|_| AppError::bad_request("invalid integer field"))
}

async fn parse_u32_field(field: axum::extract::multipart::Field<'_>) -> AppResult<u32> {
    field
        .text()
        .await
        .map_err(|_| AppError::bad_request("invalid multipart field"))?
        .parse::<u32>()
        .map_err(|_| AppError::bad_request("invalid integer field"))
}

fn map_storage_error(error: StorageError) -> AppError {
    match error {
        StorageError::MissingFile
        | StorageError::UnsupportedFormat
        | StorageError::FileTooLarge
        | StorageError::InvalidMetadata
        | StorageError::Image(_) => AppError::bad_request(error_message(&error)),
        StorageError::Io(_) => AppError::internal_server_error(error_message(&error)),
    }
}

fn error_message(error: &StorageError) -> &'static str {
    match error {
        StorageError::MissingFile => "missing file",
        StorageError::UnsupportedFormat => "unsupported format",
        StorageError::FileTooLarge => "file too large",
        StorageError::InvalidMetadata => "invalid metadata",
        StorageError::Io(_) => "failed to store file",
        StorageError::Image(_) => "unsupported format",
    }
}

fn require_allowed_content_type(content_type: Option<&str>, allowed: &[&str]) -> AppResult<()> {
    match content_type {
        Some(value) if allowed.iter().any(|candidate| *candidate == value) => Ok(()),
        _ => Err(AppError::bad_request("unsupported format")),
    }
}
