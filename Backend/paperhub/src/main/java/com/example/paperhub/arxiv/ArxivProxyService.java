package com.example.paperhub.arxiv;

import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

/**
 * HTTP proxy that fetches raw Atom XML from the arXiv API.
 * Handles error translation into the application's common exception hierarchy.
 */
@Service
public class ArxivProxyService {

    private static final Logger log = LoggerFactory.getLogger(ArxivProxyService.class);
    private static final String ARXIV_API_BASE_URL = "https://export.arxiv.org/api/query";

    private final RestTemplate restTemplate;

    public ArxivProxyService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    /**
     * Fetch raw Atom XML response from arXiv API for the given paper ID.
     *
     * @param arxivId trimmed arXiv identifier (e.g. "1512.03385")
     * @return raw Atom XML response body
     * @throws NotFoundException  if arXiv returns 404 or the paper does not exist
     * @throws BadRequestException if arXiv returns another 4xx, or a network error occurs
     */
    public String fetchRawXml(String arxivId) {
        String url = ARXIV_API_BASE_URL + "?id_list=" + arxivId;

        log.info("Fetching arXiv metadata for id: {}", arxivId);

        HttpHeaders headers = new HttpHeaders();
        headers.set("User-Agent", "PaperHub/1.0 (Academic Research Tool)");
        headers.set("Accept", "application/atom+xml");
        HttpEntity<?> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<String> response = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
            String body = response.getBody();
            log.info("Received response, length: {}", body != null ? body.length() : 0);
            return body;
        } catch (HttpClientErrorException.NotFound e) {
            throw new NotFoundException("arXiv paper not found: " + arxivId);
        } catch (HttpClientErrorException e) {
            throw new BadRequestException("arXiv API error: " + e.getStatusCode().value() + " - " + e.getMessage());
        } catch (ResourceAccessException e) {
            throw new BadRequestException("Cannot connect to arXiv API: " + e.getMessage());
        } catch (Exception e) {
            throw new BadRequestException("Failed to fetch arXiv metadata: " + e.getMessage());
        }
    }
}
