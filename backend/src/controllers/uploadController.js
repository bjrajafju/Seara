import supabase from "../services/supabase.js";

const ALLOWED_BUCKETS = ["avatars", "attachments", "groups"];

// Determina o content-type correto com base na extensao quando o browser
// envia application/octet-stream
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
            contentType =
                EXTENSION_MIME_MAP[extension] ?? "application/octet-stream";
        }

        const { error: uploadError } = await supabase.storage
            .from(bucket)
            .upload(filePath, req.file.buffer, {
                contentType,
                upsert: false,
            });

        if (uploadError) throw uploadError;

        const { data } = supabase.storage.from(bucket).getPublicUrl(filePath);

        res.status(201).json({
            url: data.publicUrl,
            content_type: contentType,
            file_name: originalName,
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro ao fazer upload." });
    }
};
