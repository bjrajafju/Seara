import axios from "axios";
import * as cheerio from "cheerio";

/// Fetches metadata for URL previews.
export const getLinkPreview = async (req, res) => {
    const { url } = req.query;

    if (!url) {
        return res.status(400).json({ error: "URL obrigatório" });
    }

    try {
        const response = await axios.get(url, {
            timeout: 5000,
            headers: {
                "User-Agent":
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            },
        });

        const html = response.data;
        const $ = cheerio.load(html);

        const getMetaTag = (names) => {
            for (const name of names) {
                const element = $(
                    `meta[property='${name}'], meta[name='${name}']`,
                );
                const content = element.attr("content");
                if (content && content.trim().length > 0) {
                    return content.trim();
                }
            }
            return null;
        };

        const title =
            getMetaTag(["og:title", "twitter:title"]) ||
            $("title").text().trim() ||
            null;
        const description = getMetaTag([
            "og:description",
            "twitter:description",
            "description",
        ]);
        const imageUrl = getMetaTag(["og:image", "twitter:image", "image"]);

        return res.json({
            title,
            description,
            imageUrl,
            url,
        });
    } catch (err) {
        console.error("getLinkPreview error:", err.message);
        /// Returns null preview data when metadata scraping fails.
        return res.json(null);
    }
};
