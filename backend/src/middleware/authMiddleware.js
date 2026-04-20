import supabase from "../services/supabase.js";

// Middleware that protects private routes.
export const authenticate = async (req, res, next) => {
  try {
    // Reads bearer token from Authorization header.
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({ error: "Token não fornecido." });
    }

    const token = authHeader.split(" ")[1];

    if (!token) {
      return res.status(401).json({ error: "Token inválido." });
    }

    // Validates token against Supabase auth.
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      return res.status(401).json({ error: "Token inválido ou expirado." });
    }

    // Guarda o utilizador na request
    req.user = data.user;

    // Passes control to the next middleware.
    next();
  } catch (err) {
    console.error("Erro no middleware de autenticação:", err);
    res.status(500).json({ error: "Erro interno no servidor." });
  }
};
