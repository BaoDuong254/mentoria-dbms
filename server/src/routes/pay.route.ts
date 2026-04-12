import express, { Router } from "express";
import { createCheckoutSession, handleWebhook, verifySession } from "@/controllers/pay.controller";
import { protectRoute } from "@/middlewares/auth.middleware";

const router: Router = express.Router();

router.post("/checkout-session", protectRoute, createCheckoutSession);
router.get("/verify-session", protectRoute, verifySession);
router.post("/webhook", handleWebhook);

export default router;
