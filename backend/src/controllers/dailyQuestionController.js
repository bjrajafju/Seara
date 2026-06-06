import supabase from "../services/supabase.js";
import { getTodayDateGMT0 } from "../utils/dateUtils.js";

/**
 * Controller para a funcionalidade "Pergunta do Dia".
 */

export const getTodayQuestion = async (req, res) => {
    try {
        const today = getTodayDateGMT0();
        const userId = req.user.id;

        // 1. Tentar buscar a pergunta já atribuída ao dia de hoje
        let { data: question, error: qError } = await supabase
            .from("daily_questions")
            .select("*")
            .eq("date", today)
            .maybeSingle();

        if (qError) throw qError;

        // 2. Se não houver pergunta para hoje, selecionar uma da pool (aleatória)
        if (!question) {
            // Busca perguntas que ainda não foram usadas (date is null ou vazio)
            // Para consistência concorrente simplificada: pegamos todas sem data e escolhemos uma determinística ou aleatória.
            // Aqui vamos buscar uma aleatória da pool.
            const { data: pool, error: pError } = await supabase
                .from("daily_questions")
                .select("*")
                .is("date", null);

            if (pError) throw pError;

            if (!pool || pool.length === 0) {
                // Se a pool estiver vazia, pegamos qualquer uma aleatória para não deixar vazio,
                // mas não atualizamos a data no banco para preservar o histórico.
                const { data: allQuestions, error: aError } = await supabase
                    .from("daily_questions")
                    .select("*");
                
                if (aError) throw aError;
                if (!allQuestions || allQuestions.length === 0) {
                    return res.status(404).json({ error: "Nenhuma pergunta disponível na base de dados." });
                }
                
                const seed = parseInt(today.replace(/-/g, ""));
                question = allQuestions[seed % allQuestions.length];
            } else {
                // Escolhe uma aleatória da pool
                const randomIndex = Math.floor(Math.random() * pool.length);
                question = pool[randomIndex];

                // Atribui ao dia de hoje
                const { error: uError } = await supabase
                    .from("daily_questions")
                    .update({ date: today })
                    .eq("id", question.id);
                
                if (uError) {
                    // Em caso de erro de concorrência (ex: outro processo já atribuiu), buscamos novamente
                    const { data: retryQuestion } = await supabase
                        .from("daily_questions")
                        .select("*")
                        .eq("date", today)
                        .maybeSingle();
                    if (retryQuestion) question = retryQuestion;
                }
            }
        }

        // 3. Verificar se o utilizador já respondeu hoje
        const { data: userAnswer, error: ansError } = await supabase
            .from("user_daily_answers")
            .select("*")
            .eq("user_id", userId)
            .eq("question_id", question.id)
            .maybeSingle();

        if (ansError) throw ansError;

        // 4. Calcular Global Accuracy
        const { count: totalAnswers } = await supabase
            .from("user_daily_answers")
            .select("*", { count: "exact", head: true })
            .eq("question_id", question.id);

        const { count: correctAnswers } = await supabase
            .from("user_daily_answers")
            .select("*", { count: "exact", head: true })
            .eq("question_id", question.id)
            .eq("is_correct", true);

        const globalAccuracy = totalAnswers > 0 ? (correctAnswers / totalAnswers) * 100 : 0;

        return res.json({
            question: {
                id: question.id,
                date: question.date,
                question: question.question,
                option_a: question.option_a,
                option_b: question.option_b,
                option_c: question.option_c,
                option_d: question.option_d,
                topic: question.topic,
            },
            answeredToday: !!userAnswer,
            userAnswer: userAnswer ? {
                selected_option: userAnswer.selected_option,
                is_correct: userAnswer.is_correct,
                answered_at: userAnswer.answered_at
            } : null,
            globalAccuracy: parseFloat(globalAccuracy.toFixed(2)),
            explanation: question.explanation,
            correctOption: question.correct_option
        });

    } catch (err) {
        console.error("Erro em getTodayQuestion:", err);
        return res.status(500).json({ error: err.message });
    }
};

export const answerDailyQuestion = async (req, res) => {
    try {
        const { question_id, selected_option } = req.body;
        const userId = req.user?.id;
        const todayStr = getTodayDateGMT0();

        if (!question_id || !selected_option) {
            return res.status(400).json({ error: "question_id e selected_option são obrigatórios." });
        }

        if (!userId) {
            return res.status(401).json({ error: "Utilizador não autenticado." });
        }

        // 1. Verificar se o utilizador existe na tabela users (evita erro de FK)
        const { data: userRecord, error: uError } = await supabase
            .from("users")
            .select("id")
            .eq("auth_id", userId)
            .maybeSingle();
        
        if (uError) throw uError;
        if (!userRecord) {
            return res.status(403).json({ error: "Perfil de utilizador não encontrado no sistema." });
        }

        // 2. Obter a pergunta oficial de hoje
        const { data: todayQuestion, error: todayQError } = await supabase
            .from("daily_questions")
            .select("id, correct_option, explanation")
            .eq("date", todayStr)
            .maybeSingle();

        if (todayQError) throw todayQError;

        if (!todayQuestion) {
            return res.status(404).json({ error: "Nenhuma pergunta disponível para hoje." });
        }

        if (todayQuestion.id !== question_id) {
            return res.status(400).json({ error: "Esta pergunta não corresponde à pergunta do dia." });
        }

        // 3. Impedir múltiplas respostas
        const { data: existingAnswer, error: checkError } = await supabase
            .from("user_daily_answers")
            .select("answered_at")
            .eq("user_id", userId)
            .eq("question_id", question_id)
            .maybeSingle();

        if (checkError) throw checkError;

        if (existingAnswer) {
            return res.status(400).json({ error: "Já respondeu à pergunta de hoje." });
        }

        // 4. Calcular isCorrect
        const selOpt = String(selected_option).toUpperCase().trim();
        const corOpt = String(todayQuestion.correct_option).toUpperCase().trim();
        const isCorrect = selOpt === corOpt;

        // 5. Guardar resposta
        const { error: insertError } = await supabase
            .from("user_daily_answers")
            .insert({
                user_id: userId,
                question_id: question_id,
                selected_option: selOpt,
                is_correct: isCorrect
            });

        if (insertError) throw insertError;

        // 6. Calcular Global Accuracy
        const { count: totalAnswers } = await supabase
            .from("user_daily_answers")
            .select("*", { count: "exact", head: true })
            .eq("question_id", question_id);

        const { count: correctAnswers } = await supabase
            .from("user_daily_answers")
            .select("*", { count: "exact", head: true })
            .eq("question_id", question_id)
            .eq("is_correct", true);

        const tCount = totalAnswers || 0;
        const cCount = correctAnswers || 0;
        const globalAccuracy = tCount > 0 ? (cCount / tCount) * 100 : 0;

        return res.json({
            isCorrect,
            explanation: todayQuestion.explanation,
            globalAccuracy: parseFloat(globalAccuracy.toFixed(2)),
            correctOption: todayQuestion.correct_option
        });

    } catch (err) {
        console.error("Erro em answerDailyQuestion:", err);
        return res.status(500).json({ 
            error: "Erro interno ao processar a resposta.",
            message: err.message
        });
    }
};

export const getStreak = async (req, res) => {
    try {
        const userId = req.user.id;
        const today = getTodayDateGMT0();

        // 1. Verificar se respondeu hoje
        // Precisamos saber a pergunta de hoje para verificar na user_daily_answers
        const { data: todayQ } = await supabase
            .from("daily_questions")
            .select("id")
            .eq("date", today)
            .maybeSingle();

        let answeredToday = false;
        if (todayQ) {
            const { data: ansToday } = await supabase
                .from("user_daily_answers")
                .select("*")
                .eq("user_id", userId)
                .eq("question_id", todayQ.id)
                .maybeSingle();
            answeredToday = !!ansToday;
        }

        // 2. Calcular Streak
        // Vamos buscar as respostas do utilizador ordenadas por data desc
        // Como o streak é diário, vamos verificar os dias consecutivos para trás.
        
        // Obter todas as datas únicas que o utilizador respondeu, ordenadas
        const { data: history, error: hError } = await supabase
            .from("user_daily_answers")
            .select("answered_at")
            .eq("user_id", userId)
            .order("answered_at", { ascending: false });

        if (hError) throw hError;

        let streak = 0;
        if (history && history.length > 0) {
            // Converter answered_at para datas (YYYY-MM-DD) UTC e remover duplicatas
            const answeredDates = [...new Set(history.map(h => {
                const d = new Date(h.answered_at);
                return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
            }))];

            const todayStr = getTodayDateGMT0();
            
            // Gerar ontem em UTC
            const yesterdayDate = new Date();
            yesterdayDate.setUTCDate(yesterdayDate.getUTCDate() - 1);
            const yesterdayStr = `${yesterdayDate.getUTCFullYear()}-${String(yesterdayDate.getUTCMonth() + 1).padStart(2, "0")}-${String(yesterdayDate.getUTCDate()).padStart(2, "0")}`;

            // Determinar o ponto de partida do streak
            let currentCheckDate = new Date();
            let checkStr = todayStr;

            if (!answeredDates.includes(todayStr)) {
                // Se não respondeu hoje, verificamos se respondeu ontem
                if (answeredDates.includes(yesterdayStr)) {
                    // Começamos a contagem de ontem
                    checkStr = yesterdayStr;
                    currentCheckDate.setUTCDate(currentCheckDate.getUTCDate() - 1);
                } else {
                    // Não respondeu nem hoje nem ontem, streak resetado
                    return res.json({ streak: 0, answeredToday: false });
                }
            }

            // Contar dias consecutivos para trás
            while (answeredDates.includes(checkStr)) {
                streak++;
                currentCheckDate.setUTCDate(currentCheckDate.getUTCDate() - 1);
                checkStr = `${currentCheckDate.getUTCFullYear()}-${String(currentCheckDate.getUTCMonth() + 1).padStart(2, "0")}-${String(currentCheckDate.getUTCDate()).padStart(2, "0")}`;
            }
        }

        return res.json({
            streak,
            answeredToday
        });

    } catch (err) {
        console.error("Erro em getStreak:", err);
        return res.status(500).json({ error: err.message });
    }
};
