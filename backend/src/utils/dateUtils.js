/**
 * Retorna a data atual no formato YYYY-MM-DD em GMT+0 (UTC).
 * @returns {string}
 */
export const getTodayDateGMT0 = () => {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = String(now.getUTCMonth() + 1).padStart(2, "0");
    const day = String(now.getUTCDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
};
