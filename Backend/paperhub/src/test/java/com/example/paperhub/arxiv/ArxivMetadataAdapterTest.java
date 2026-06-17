package com.example.paperhub.arxiv;

import com.example.paperhub.arxiv.dto.ArxivMetadataDto;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ArxivMetadataAdapterTest {

    private final ArxivMetadataAdapter adapter = new ArxivMetadataAdapter();

    private static final String VALID_XML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:arxiv="http://arxiv.org/schemas/atom"
                  xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
              <opensearch:totalResults>1</opensearch:totalResults>
              <entry>
                <id>http://arxiv.org/abs/1512.03385v1</id>
                <arxiv:arxiv_id>1512.03385</arxiv:arxiv_id>
                <title>  Deep   Residual\n Learning  </title>
                <author><name>Kaiming He</name></author>
                <author><name>Xiangyu Zhang</name></author>
                <summary>  Deeper neural networks\nare more difficult to train.  </summary>
                <published>2015-12-10T00:00:00Z</published>
                <category term="cs.CV"/>
                <category term="cs.LG"/>
                <arxiv:doi>10.1109/CVPR.2016.90</arxiv:doi>
                <arxiv:journal_ref>CVPR 2016</arxiv:journal_ref>
              </entry>
            </feed>
            """;

    private static final String ZERO_RESULTS_XML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
              <opensearch:totalResults>0</opensearch:totalResults>
            </feed>
            """;

    private static final String MINIMAL_XML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
              <opensearch:totalResults>1</opensearch:totalResults>
              <entry>
                <id>http://arxiv.org/abs/2301.00001v1</id>
                <title>Minimal Paper</title>
                <published>2023-01-01T00:00:00Z</published>
              </entry>
            </feed>
            """;

    @Test
    void parseValidXmlExtractsAllFields() {
        ArxivMetadataDto dto = adapter.parseXml(VALID_XML, "1512.03385");

        assertThat(dto.id()).isEqualTo("1512.03385");
        assertThat(dto.title()).isEqualTo("Deep Residual Learning");
        assertThat(dto.authors()).containsExactly("Kaiming He", "Xiangyu Zhang");
        assertThat(dto.abstractText()).isEqualTo("Deeper neural networks are more difficult to train.");
        assertThat(dto.publishedDate()).isEqualTo("2015-12-10T00:00:00Z");
        assertThat(dto.categories()).containsExactly("cs.CV", "cs.LG");
        assertThat(dto.doi()).isEqualTo("10.1109/CVPR.2016.90");
        assertThat(dto.journal()).isEqualTo("CVPR 2016");
    }

    @Test
    void parseZeroResultsThrowsNotFoundException() {
        assertThatThrownBy(() -> adapter.parseXml(ZERO_RESULTS_XML, "9999.99999"))
                .isInstanceOf(NotFoundException.class)
                .hasMessageContaining("9999.99999");
    }

    @Test
    void parseNullXmlThrowsNotFoundException() {
        assertThatThrownBy(() -> adapter.parseXml(null, "1512.03385"))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void parseBlankXmlThrowsNotFoundException() {
        assertThatThrownBy(() -> adapter.parseXml("   ", "1512.03385"))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void parseMinimalXmlWithMissingFieldsReturnsNullForOptionalFields() {
        ArxivMetadataDto dto = adapter.parseXml(MINIMAL_XML, "2301.00001");

        assertThat(dto.id()).isEqualTo("http://arxiv.org/abs/2301.00001v1"); // falls back to atom:id
        assertThat(dto.title()).isEqualTo("Minimal Paper");
        assertThat(dto.authors()).isEmpty();
        assertThat(dto.abstractText()).isNull();
        assertThat(dto.publishedDate()).isEqualTo("2023-01-01T00:00:00Z");
        assertThat(dto.categories()).isEmpty();
        assertThat(dto.doi()).isNull();
        assertThat(dto.journal()).isNull();
    }

    @Test
    void parseInvalidXmlThrowsBadRequestException() {
        assertThatThrownBy(() -> adapter.parseXml("not valid xml", "1512.03385"))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void parseXmlWithNoEntryThrowsNotFoundException() {
        String xml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <feed xmlns="http://www.w3.org/2005/Atom"
                      xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
                  <opensearch:totalResults>1</opensearch:totalResults>
                </feed>
                """;
        assertThatThrownBy(() -> adapter.parseXml(xml, "1512.03385"))
                .isInstanceOf(NotFoundException.class);
    }
}
