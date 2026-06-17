package com.example.paperhub.arxiv;

import com.example.paperhub.arxiv.dto.ArxivMetadataDto;
import com.example.paperhub.common.exception.BadRequestException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * arXiv API proxy controller.
 * <p>
 * Provides two endpoints:
 * <ul>
 *   <li><b>GET /arxiv?id=XXX</b> — returns raw Atom XML (backward-compatible with existing frontend)</li>
 *   <li><b>GET /arxiv/metadata?id=XXX</b> — returns structured JSON parsed from the Atom response</li>
 * </ul>
 */
@RestController
@RequestMapping("/arxiv")
@CrossOrigin(origins = "*")
public class ArxivController {

    private static final Logger log = LoggerFactory.getLogger(ArxivController.class);

    private final ArxivProxyService arxivProxyService;
    private final ArxivMetadataAdapter arxivMetadataAdapter;

    public ArxivController(ArxivProxyService arxivProxyService, ArxivMetadataAdapter arxivMetadataAdapter) {
        this.arxivProxyService = arxivProxyService;
        this.arxivMetadataAdapter = arxivMetadataAdapter;
    }

    /**
     * Fetch raw Atom XML from arXiv (backward-compatible).
     * The frontend's {@code ArxivService} parses the XML client-side.
     */
    @GetMapping
    public ResponseEntity<String> getArxivXml(@RequestParam String id) {
        String cleanId = validateAndCleanId(id);
        String xml = arxivProxyService.fetchRawXml(cleanId);
        return ResponseEntity.ok()
                .header("Content-Type", "application/xml; charset=utf-8")
                .body(xml);
    }

    /**
     * Fetch parsed arXiv metadata as structured JSON.
     */
    @GetMapping("/metadata")
    public ResponseEntity<ArxivMetadataDto> getArxivMetadata(@RequestParam String id) {
        String cleanId = validateAndCleanId(id);
        String xml = arxivProxyService.fetchRawXml(cleanId);
        ArxivMetadataDto metadata = arxivMetadataAdapter.parseXml(xml, cleanId);
        return ResponseEntity.ok(metadata);
    }

    private String validateAndCleanId(String id) {
        if (id == null || id.trim().isEmpty()) {
            throw new BadRequestException("arXiv ID cannot be empty");
        }
        return id.trim();
    }
}
