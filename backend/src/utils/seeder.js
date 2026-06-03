import supabase from "../services/supabase.js";

const questions = [
    {
        question: "Qual é a capital de Portugal?",
        option_a: "Porto",
        option_b: "Lisboa",
        option_c: "Coimbra",
        option_d: "Braga",
        correct_option: "B",
        explanation: "Lisboa é a capital e a maior cidade de Portugal.",
        topic: "Geografia"
    },
    {
        question: "Quem pintou a Mona Lisa?",
        option_a: "Vincent van Gogh",
        option_b: "Pablo Picasso",
        option_c: "Leonardo da Vinci",
        option_d: "Claude Monet",
        correct_option: "C",
        explanation: "A Mona Lisa foi pintada por Leonardo da Vinci no século XVI.",
        topic: "Arte"
    },
    {
        question: "Qual é o maior planeta do sistema solar?",
        option_a: "Terra",
        option_b: "Marte",
        option_c: "Saturno",
        option_d: "Júpiter",
        correct_option: "D",
        explanation: "Júpiter é o maior planeta do nosso sistema solar, tanto em termos de massa quanto de volume.",
        topic: "Ciência"
    },
    {
        question: "Em que ano começou a Segunda Guerra Mundial?",
        option_a: "1914",
        option_b: "1939",
        option_c: "1945",
        option_d: "1918",
        correct_option: "B",
        explanation: "A Segunda Guerra Mundial começou em 1 de setembro de 1939, com a invasão da Polônia pela Alemanha.",
        topic: "História"
    },
    {
        question: "Qual é o elemento químico com o símbolo 'O'?",
        option_a: "Ouro",
        option_b: "Osmio",
        option_c: "Oxigénio",
        option_d: "Ondina",
        correct_option: "C",
        explanation: "O símbolo 'O' na tabela periódica representa o Oxigénio.",
        topic: "Química"
    },
    {
        question: "Qual é a velocidade da luz no vácuo (aproximadamente)?",
        option_a: "300.000 km/s",
        option_b: "150.000 km/s",
        option_c: "1.000.000 km/s",
        option_d: "30.000 km/s",
        correct_option: "A",
        explanation: "A velocidade da luz no vácuo é de aproximadamente 299.792.458 metros por segundo.",
        topic: "Física"
    },
    {
        question: "Em que continente fica o deserto do Saara?",
        option_a: "Ásia",
        option_b: "América",
        option_c: "África",
        option_d: "Oceania",
        correct_option: "C",
        explanation: "O deserto do Saara está localizado no norte do continente africano.",
        topic: "Geografia"
    },
    {
        question: "Qual é o animal terrestre mais rápido do mundo?",
        option_a: "Leão",
        option_b: "Guepardo",
        option_c: "Antílope",
        option_d: "Cavalo",
        correct_option: "B",
        explanation: "O guepardo (chita) pode atingir velocidades de até 110-120 km/h.",
        topic: "Biologia"
    },
    {
        question: "Quem escreveu 'Os Lusíadas'?",
        option_a: "Fernando Pessoa",
        option_b: "José Saramago",
        option_c: "Luís de Camões",
        option_d: "Eça de Queirós",
        correct_option: "C",
        explanation: "Luís de Camões publicou 'Os Lusíadas' em 1572, celebrando os feitos dos portugueses.",
        topic: "Literatura"
    },
    {
        question: "Quantos planetas existem no sistema solar?",
        option_a: "7",
        option_b: "8",
        option_c: "9",
        option_d: "10",
        correct_option: "B",
        explanation: "Atualmente, o sistema solar é composto por 8 planetas oficiais (Plutão é considerado planeta anão).",
        topic: "Ciência"
    }
];

export const seedQuestions = async () => {
    console.log("Iniciando seeding de perguntas...");
    const { data, error } = await supabase
        .from("daily_questions")
        .insert(questions);

    if (error) {
        console.error("Erro ao inserir perguntas:", error);
    } else {
        console.log("Perguntas inseridas com sucesso!");
    }
};

// Se executado diretamente
if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, '/')}`) {
    seedQuestions();
}
