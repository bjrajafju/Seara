import express from "express";
import { authenticate } from "../middleware/authMiddleware.js";
import multer from "multer";
import { uploadFile } from "../controllers/uploadController.js";

const storage = multer.memoryStorage();

const upload = multer({
    storage,
    limits: {
        fileSize: 50 * 1024 * 1024, // 50 MB
    },
    fileFilter: (req, file, cb) => {
        // Aceitar todos os tipos de ficheiro
        cb(null, true);
    },
});

const router = express.Router();

router.use(authenticate);

router.post("/:bucket", upload.single("file"), uploadFile);

export default router;
