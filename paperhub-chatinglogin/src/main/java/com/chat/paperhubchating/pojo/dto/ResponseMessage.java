package com.chat.paperhubchating.pojo.dto;

import org.springframework.http.HttpStatus;

public class ResponseMessage<T> {
    private Integer code;
    private String message;
    private T data;

    // 接口请求成功
    public static <T> ResponseMessage<T> success(String message, T data) {
        return new ResponseMessage<>(HttpStatus.OK.value(), "success", data);
    }

    // 接口请求失败
    public static <T> ResponseMessage<T> error(String message, T data) {
        ResponseMessage<T> response = new ResponseMessage<>(HttpStatus.BAD_REQUEST.value(), message, data);
        System.out.println("接口请求失败: code=" + response.getCode() + ", message=" + response.getMessage() + ", data=" + response.getData());
        return response;
    }



    public ResponseMessage(Integer code, String message, T data) {
        this.code = code;
        this.message = message;
        this.data = data;
    }

    public Integer getCode() {
        return code;
    }

    public void setCode(Integer code) {
        this.code = code;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public T getData() {
        return data;
    }

    public void setData(T data) {
        this.data = data;
    }

}
