import supabase from "../services/supabase.js";

const ALLOWED_BUCKETS = ["avatars", "attachments", "groups"];

export const uploadImage = async (req, res) => {
    const { bucket } = req.params;

    if (!ALLOWED_BUCKETS.includes(bucket)) {
        return res.status(400).json({ error: "Bucket invalido." });
    }

    if (!req.file) {
        return res.status(400).json({ error: "Nenhum ficheiro recebido." });
    }

    try {
        const timestamp = Date.now();
        const originalName = req.file.originalname || "image.jpg";
        const extension = originalName.split(".").pop() || "jpg";
        const filePath = `${timestamp}.${extension}`;

        // Determinar content-type: usar o do ficheiro ou fallback para jpeg
        const contentType =
            req.file.mimetype === "application/octet-stream"
                ? "image/jpeg"
                : req.file.mimetype;

        const { error: uploadError } = await supabase.storage
            .from(bucket)
            .upload(filePath, req.file.buffer, {
                contentType,
                upsert: false,
            });

        if (uploadError) throw uploadError;

        const { data } = supabase.storage.from(bucket).getPublicUrl(filePath);

        res.status(201).json({ url: data.publicUrl });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erro ao fazer upload." });
    }
};
