import express from "express";
import multer from "multer";
import { uploadImage } from "../controllers/uploadController.js";

const storage = multer.memoryStorage();

const upload = multer({
    storage,
    limits: {
        fileSize: 10 * 1024 * 1024,
    },
    fileFilter: (req, file, cb) => {
        // Aceitar mesmo quando o browser nao envia mimetype correto
        const allowed = [
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/gif",
            "application/octet-stream",
        ];
        if (allowed.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error("Tipo de ficheiro nao permitido."));
        }
    },
});

const router = express.Router();

router.post("/:bucket", upload.single("file"), uploadImage);

export default router;
