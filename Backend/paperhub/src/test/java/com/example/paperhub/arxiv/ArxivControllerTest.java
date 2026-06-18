package com.example.paperhub.arxiv;

import com.example.paperhub.arxiv.dto.ArxivMetadataDto;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(controllers = ArxivController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class ArxivControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ArxivProxyService arxivProxyService;
    @MockBean
    private ArxivMetadataAdapter arxivMetadataAdapter;
    @MockBean
    private com.example.paperhub.jwt.JwtService jwtService;
    @MockBean
    private com.example.paperhub.auth.UserRepository userRepository;
    @MockBean
    private com.example.paperhub.jwt.TokenBlacklistService tokenBlacklistService;

    private static final String SAMPLE_XML = "<feed xmlns=\"http://www.w3.org/2005/Atom\"><entry>" +
            "<id>http://arxiv.org/abs/1512.03385</id>" +
            "<title>Deep Residual Learning</title>" +
            "<author><name>Kaiming He</name></author>" +
            "<summary>Deeper neural networks are more difficult to train.</summary>" +
            "<published>2015-12-10T00:00:00Z</published>" +
            "<category term=\"cs.CV\"/>" +
            "</entry></feed>";

    @Test
    void getArxivXmlReturnsXmlContentType() throws Exception {
        when(arxivProxyService.fetchRawXml("1512.03385")).thenReturn(SAMPLE_XML);

        mockMvc.perform(get("/arxiv").param("id", "1512.03385"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "application/xml; charset=utf-8"));
    }

    @Test
    void getArxivXmlBlankIdReturns400() throws Exception {
        mockMvc.perform(get("/arxiv").param("id", "  ").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void getArxivMetadataReturnsJson() throws Exception {
        when(arxivProxyService.fetchRawXml("1512.03385")).thenReturn(SAMPLE_XML);
        ArxivMetadataDto dto = new ArxivMetadataDto(
                "1512.03385", "Deep Residual Learning", List.of("Kaiming He"),
                "Deeper neural networks are more difficult to train.",
                "2015-12-10T00:00:00Z", List.of("cs.CV"), null, null, null
        );
        when(arxivMetadataAdapter.parseXml(SAMPLE_XML, "1512.03385")).thenReturn(dto);

        mockMvc.perform(get("/arxiv/metadata").param("id", "1512.03385"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("1512.03385"))
                .andExpect(jsonPath("$.title").value("Deep Residual Learning"))
                .andExpect(jsonPath("$.authors[0]").value("Kaiming He"))
                .andExpect(jsonPath("$.categories[0]").value("cs.CV"));
    }

    @Test
    void getArxivMetadataNotFoundReturns404() throws Exception {
        when(arxivProxyService.fetchRawXml("9999.99999")).thenThrow(new NotFoundException("arXiv paper not found: 9999.99999"));

        mockMvc.perform(get("/arxiv/metadata").param("id", "9999.99999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404));
    }

    @Test
    void getArxivMetadataBlankIdReturns400() throws Exception {
        mockMvc.perform(get("/arxiv/metadata").param("id", "").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void getArxivMetadataMissingIdParamReturnsServerError() throws Exception {
        // Spring throws MissingServletRequestParameterException before controller runs.
        // GlobalExceptionHandler does not map this to 400 — existing behavior preserved.
        mockMvc.perform(get("/arxiv/metadata").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().is5xxServerError());
    }
}
