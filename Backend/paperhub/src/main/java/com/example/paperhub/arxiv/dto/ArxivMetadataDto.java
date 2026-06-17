package com.example.paperhub.arxiv.dto;

import java.util.List;

/**
 * arXiv paper metadata parsed from Atom XML response.
 * Null/empty fields indicate the data was absent from the API response.
 */
public record ArxivMetadataDto(
        String id,
        String title,
        List<String> authors,
        String abstractText,
        String publishedDate,
        List<String> categories,
        String doi,
        String journal,
        String comment) {
}
