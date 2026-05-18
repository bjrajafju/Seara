import { supabaseAdmin } from "../services/supabase.js";

const ALLOWED_BUCKETS = ["avatars", "attachments", "groups", "stories"];

/// Resolves content type from file extension when needed.
/// Handles uploads sent as application/octet-stream.
const EXTENSION_MIME_MAP = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  gif: "image/gif",
  mp4: "video/mp4",
  mov: "video/quicktime",
  avi: "video/x-msvideo",
  mp3: "audio/mpeg",
  m4a: "audio/mp4",
  aac: "audio/aac",
  wav: "audio/wav",
  ogg: "audio/ogg",
  pdf: "application/pdf",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  zip: "application/zip",
};

export const uploadFile = async (req, res) => {
  const { bucket } = req.params;

  console.log(`[UploadAPI] Request received for bucket: ${bucket}`);
  if (req.file) {
    console.log(`[UploadAPI] req.file details:`, {
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
    });
  } else {
    console.log(`[UploadAPI] req.file is undefined!`);
  }

  if (!ALLOWED_BUCKETS.includes(bucket)) {
    return res.status(400).json({ error: "Bucket invalido." });
  }

  if (!req.file) {
    return res.status(400).json({ error: "Nenhum ficheiro recebido." });
  }

  try {
    const timestamp = Date.now();
    const originalName = req.file.originalname || "file";
    const extension = originalName.split(".").pop()?.toLowerCase() || "bin";
    const filePath = `${timestamp}.${extension}`;

    let contentType = req.file.mimetype;
    if (contentType === "application/octet-stream") {
      contentType = EXTENSION_MIME_MAP[extension] ?? "application/octet-stream";
    }

    console.log(`[UploadAPI] Target filePath: ${filePath}, resolved contentType: ${contentType}`);

    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucket)
      .upload(filePath, req.file.buffer, {
        contentType,
        upsert: false,
      });

    if (uploadError) {
      console.error(`[UploadAPI] Supabase Storage upload error:`, uploadError);
      throw uploadError;
    }

    const { data } = supabaseAdmin.storage.from(bucket).getPublicUrl(filePath);
    console.log(`[UploadAPI] Upload succeeded! Public URL: ${data.publicUrl}`);

    res.status(201).json({
      url: data.publicUrl,
      content_type: contentType,
      file_name: originalName,
    });
  } catch (err) {
    console.error(`[UploadAPI] Unexpected catch error:`, err);
    res.status(500).json({ error: err.message || "Erro ao fazer upload." });
  }
};
