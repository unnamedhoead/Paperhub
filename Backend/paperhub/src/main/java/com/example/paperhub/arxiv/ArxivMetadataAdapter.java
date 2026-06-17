package com.example.paperhub.arxiv;

import com.example.paperhub.arxiv.dto.ArxivMetadataDto;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Parses Atom XML returned by the arXiv API into {@link ArxivMetadataDto}.
 * <p>
 * The XML uses namespaces:
 * <ul>
 *   <li>Atom: {@code http://www.w3.org/2005/Atom}</li>
 *   <li>arXiv: {@code http://arxiv.org/schemas/atom}</li>
 *   <li>OpenSearch: {@code http://a9.com/-/spec/opensearch/1.1/}</li>
 * </ul>
 */
@Component
public class ArxivMetadataAdapter {

    private static final Logger log = LoggerFactory.getLogger(ArxivMetadataAdapter.class);

    private static final String ATOM_NS = "http://www.w3.org/2005/Atom";
    private static final String ARXIV_NS = "http://arxiv.org/schemas/atom";
    private static final String OPENSEARCH_NS = "http://a9.com/-/spec/opensearch/1.1/";

    /**
     * Parse the Atom XML response into structured metadata.
     *
     * @param xml         raw Atom XML from arXiv API
     * @param requestedId the arXiv ID that was requested (used in error messages)
     * @return parsed metadata DTO; optional fields may be null
     * @throws NotFoundException  if the XML indicates zero results
     * @throws BadRequestException if XML parsing fails
     */
    public ArxivMetadataDto parseXml(String xml, String requestedId) {
        if (xml == null || xml.isBlank()) {
            throw new NotFoundException("arXiv paper not found: " + requestedId);
        }

        Document doc;
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            doc = factory.newDocumentBuilder()
                    .parse(new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));
        } catch (NotFoundException e) {
            throw e;
        } catch (Exception e) {
            log.error("Failed to parse arXiv XML: {}", e.getMessage());
            throw new BadRequestException("Failed to parse arXiv response: " + e.getMessage());
        }

        // Check totalResults before extracting entry data
        String totalResults = getTextContent(doc, OPENSEARCH_NS, "totalResults");
        if ("0".equals(totalResults)) {
            throw new NotFoundException("arXiv paper not found: " + requestedId);
        }

        Element entry = (Element) doc.getElementsByTagNameNS(ATOM_NS, "entry").item(0);
        if (entry == null) {
            throw new NotFoundException("arXiv paper not found: " + requestedId);
        }

        String id = getTextContent(entry, ARXIV_NS, "arxiv_id");
        if (id == null || id.isBlank()) {
            id = getTextContent(entry, ATOM_NS, "id");
        }

        String title = normalizeWhitespace(getTextContent(entry, ATOM_NS, "title"));
        String abstractText = normalizeWhitespace(getTextContent(entry, ATOM_NS, "summary"));
        String publishedDate = getTextContent(entry, ATOM_NS, "published");
        String doi = getTextContent(entry, ARXIV_NS, "doi");
        String journal = getTextContent(entry, ARXIV_NS, "journal_ref");
        String comment = getTextContent(entry, ARXIV_NS, "comment");

        List<String> authors = extractAuthors(entry);
        List<String> categories = extractCategories(entry);

        return new ArxivMetadataDto(id, title, authors, abstractText, publishedDate, categories, doi, journal, comment);
    }

    /**
     * Extract author names from {@code <author><name>} elements.
     */
    private List<String> extractAuthors(Element entry) {
        List<String> authors = new ArrayList<>();
        NodeList authorNodes = entry.getElementsByTagNameNS(ATOM_NS, "author");
        for (int i = 0; i < authorNodes.getLength(); i++) {
            Element authorElem = (Element) authorNodes.item(i);
            String name = getTextContent(authorElem, ATOM_NS, "name");
            if (name != null && !name.isBlank()) {
                authors.add(name.trim());
            }
        }
        return authors;
    }

    /**
     * Extract category terms from {@code <category term="...">} elements.
     */
    private List<String> extractCategories(Element entry) {
        List<String> categories = new ArrayList<>();
        NodeList catNodes = entry.getElementsByTagNameNS(ATOM_NS, "category");
        for (int i = 0; i < catNodes.getLength(); i++) {
            Element catElem = (Element) catNodes.item(i);
            String term = catElem.getAttribute("term");
            if (term != null && !term.isBlank()) {
                categories.add(term.trim());
            }
        }
        return categories;
    }

    /**
     * Get text content of the first child element matching the given namespace and local name.
     * Returns null if the element is not found.
     */
    private String getTextContent(Element parent, String namespace, String localName) {
        NodeList nodes = parent.getElementsByTagNameNS(namespace, localName);
        if (nodes.getLength() == 0) {
            return null;
        }
        return nodes.item(0).getTextContent();
    }

    /**
     * Get text content from the Document root using namespace.
     */
    private String getTextContent(Document doc, String namespace, String localName) {
        NodeList nodes = doc.getElementsByTagNameNS(namespace, localName);
        if (nodes.getLength() == 0) {
            return null;
        }
        return nodes.item(0).getTextContent();
    }

    /**
     * Normalize whitespace: collapse multiple spaces/newlines/tabs into a single space, then trim.
     */
    private String normalizeWhitespace(String text) {
        if (text == null) {
            return null;
        }
        return text.replaceAll("\\s+", " ").trim();
    }
}
