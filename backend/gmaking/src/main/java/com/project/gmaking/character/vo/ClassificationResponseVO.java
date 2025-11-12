package com.project.gmaking.character.vo;

import lombok.Data;
import lombok.ToString;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
@Data
@ToString
public class ClassificationResponseVO {
    private String status;

    @JsonProperty("predicted_animal")
    private String predictedAnimal;

    private double confidence;
}