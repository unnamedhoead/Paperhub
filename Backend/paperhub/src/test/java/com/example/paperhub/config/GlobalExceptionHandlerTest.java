package com.example.paperhub.config;

import com.example.paperhub.common.dto.ApiResponse;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {
    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void apiExceptionUsesConfiguredStatusCodeAndMessage() {
        ResponseEntity<ApiResponse<Object>> response =
                handler.handleApiException(new NotFoundException("用户不存在"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo(404);
        assertThat(response.getBody().message()).isEqualTo("用户不存在");
        assertThat(response.getBody().data()).isNull();
    }

    @Test
    void badRequestExceptionKeepsUnifiedResponseShape() {
        ResponseEntity<ApiResponse<Object>> response =
                handler.handleApiException(new BadRequestException("请求参数错误"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo(400);
        assertThat(response.getBody().message()).isEqualTo("请求参数错误");
        assertThat(response.getBody().data()).isNull();
    }

    @Test
    void illegalArgumentFallsBackToBadRequestShape() {
        ResponseEntity<ApiResponse<Object>> response =
                handler.handleIllegalArgumentException(new IllegalArgumentException("非法参数"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo(400);
        assertThat(response.getBody().message()).isEqualTo("非法参数");
        assertThat(response.getBody().data()).isNull();
    }
}
