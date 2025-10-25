import supabase from "../services/supabase.js";

// Rotas privadas
export const authenticate = async (req, res, next) => {
  try {
    // Token de autenticação do Authorization
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({ error: "Token não fornecido." });
    }

    const token = authHeader.split(" ")[1];

    if (!token) {
      return res.status(401).json({ error: "Token inválido." });
    }

    // Verifica a sessão/token no Supabase
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      return res.status(401).json({ error: "Token inválido ou expirado." });
    }

    // Guarda o utilizador na request
    req.user = data.user;

    // Chama a próxima função
    next();
  } catch (err) {
    console.error("Erro no middleware de autenticação:", err);
    res.status(500).json({ error: "Erro interno no servidor." });
  }
};
