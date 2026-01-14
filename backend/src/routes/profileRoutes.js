import express from "express";
import { getProfile, updateProfile, getAllUsers, followUser } from "../controllers/profileController.js";

const router = express.Router();

// temporário para fazer o perfil de outro utilizador:
router.get("/users", getAllUsers);


router.get("/me", getProfile);
router.get("/:userId", getProfile);
router.put("/:userId", updateProfile);
router.post("/follow", followUser);



export default router;

