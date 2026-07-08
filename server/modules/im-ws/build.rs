use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let manifest_dir = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR")?);
    let repo_root = manifest_dir
        .parent()
        .and_then(|path| path.parent())
        .and_then(|path| path.parent())
        .ok_or("failed to resolve repo root")?;
    let proto_dir = repo_root.join("proto");
    let proto_files = [
        repo_root.join("proto/ws.proto"),
        repo_root.join("proto/message.proto"),
    ];

    for proto_file in &proto_files {
        println!("cargo:rerun-if-changed={}", proto_file.display());
    }
    println!("cargo:rerun-if-changed={}", proto_dir.display());

    let protoc = protoc_bin_vendored::protoc_bin_path()?;
    let mut config = prost_build::Config::new();
    config.protoc_executable(protoc);
    config.compile_protos(&proto_files, &[proto_dir])?;

    Ok(())
}
