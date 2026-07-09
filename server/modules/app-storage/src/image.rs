use std::io::Cursor;

#[derive(Debug)]
pub struct ProcessedImage {
    pub width: u32,
    pub height: u32,
    pub thumb_webp: Vec<u8>,
}

pub fn process_image(bytes: &[u8]) -> Result<ProcessedImage, image::ImageError> {
    let image = image::load_from_memory(bytes)?;
    let width = image.width();
    let height = image.height();
    let thumb = image.thumbnail(200, 200);

    let mut cursor = Cursor::new(Vec::new());
    thumb.write_to(&mut cursor, image::ImageFormat::WebP)?;

    Ok(ProcessedImage {
        width,
        height,
        thumb_webp: cursor.into_inner(),
    })
}

#[cfg(test)]
mod tests {
    use super::process_image;

    #[test]
    fn process_image_generates_webp_thumb() {
        let png = [
            137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
            8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207,
            192, 240, 31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66,
            96, 130,
        ];

        let processed = process_image(&png).expect("png should parse");

        assert_eq!(processed.width, 1);
        assert_eq!(processed.height, 1);
        assert!(!processed.thumb_webp.is_empty());
    }
}
