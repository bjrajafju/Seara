import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import authRoutes from "./routes/authRoutes.js";
import profileRoutes from "./routes/profileRoutes.js";
import messagesRoutes from "./routes/messagesRoutes.js";
import uploadRoutes from "./routes/uploadRoutes.js";
import dailyQuestionRoutes from "./routes/dailyQuestionRoutes.js";
import timeRoutes from "./routes/timeRoutes.js";
import versionRoutes from "./routes/versionRoutes.js";
import { startEphemeralCleanup } from "./services/ephemeralCleanup.js";

import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, "../.env") });

const app = express();
app.use(cors());
app.use(express.json());

app.use("/auth", authRoutes);
app.use("/profile", profileRoutes);
app.use("/messages", messagesRoutes);
app.use("/upload", uploadRoutes);
app.use("/daily-question", dailyQuestionRoutes);
app.use("/time", timeRoutes);
app.use("/version", versionRoutes);
app.use("/download", express.static(path.join(__dirname, "../installers/windows")));

const PORT = process.env.PORT || 3000;
const HOST = "0.0.0.0";
app.listen(PORT, HOST, () => {
    console.log(`Servidor rodando em http://${HOST}:${PORT}`);
    /// Start ephemeral message cleanup interval
    startEphemeralCleanup();
});
