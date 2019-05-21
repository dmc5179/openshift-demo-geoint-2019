#install.packages("keras")
library(keras)
# Make sure to install required prerequisites, before installing Keras using the commands below:
install_keras() # CPU version
#install_keras(tensorflow = "gpu") # GPU version

library(keras)
library(tidyverse)
library(jsonlite)
library(abind)
library(gridExtra)

ships_json <- fromJSON("/data/ships_images/shipsnet.json")[1:2]

ships_data <- ships_json$data %>%
  apply(., 1, function(x) {
    r <- matrix(x[1:6400], 80, 80, byrow = TRUE) / 255
    g <- matrix(x[6401:12800], 80, 80, byrow = TRUE) / 255
    b <- matrix(x[12801:19200], 80, 80, byrow = TRUE) / 255
    list(array(c(r,g,b), dim = c(80, 80, 3)))
  }) %>%
  do.call(c, .) %>%
  abind(., along = 4) %>%
  aperm(c(4, 1, 2, 3))

ships_labels <- ships_json$labels %>%
  to_categorical(2)

rm(ships_json)

dim(ships_data)

xy_axis <- data.frame(x = expand.grid(1:80, 80:1)[, 1],
                      y = expand.grid(1:80, 80:1)[, 2])
set.seed(1111)
sample_plots <- sample(1:dim(ships_data)[1], 12) %>%
  map(~ {
    plot_data <- cbind(xy_axis, r = as.vector(t(ships_data[.x, , , 1])),
                       g = as.vector(t(ships_data[.x, , , 2])),
                       b = as.vector(t(ships_data[.x, , , 3])))
    ggplot(plot_data, aes(x, y, fill = rgb(r, g, b))) + guides(fill = FALSE) +
      scale_fill_identity() + theme_void() + geom_raster(hjust = 0, vjust = 0) +
      ggtitle(ifelse(ships_labels[.x, 2], "Ship", "Non-ship"))
  })

do.call("grid.arrange", c(sample_plots, ncol = 4, nrow = 3))


set.seed(1234)
indexes <- sample(1:nrow(ships_labels), 0.7 * nrow(ships_labels))
train <- list(data = ships_data[indexes, , , ], labels = ships_labels[indexes, ])
test <- list(data = ships_data[-indexes, , , ], labels = ships_labels[-indexes, ])

model <- keras_model_sequential()
#summary(model)   # Don't call this here, it is just to show it doesn't work yet

model %>%
  # 32 filters, each size 3x3 pixels
  # ReLU activation after convolution
  layer_conv_2d(
    input_shape = c(80, 80, 3),
    filter = 32, kernel_size = c(3, 3), strides = c(1, 1),
    activation = "relu") %>%
  layer_max_pooling_2d(pool_size = c(2, 2), strides = c(2, 2)) %>%
  layer_conv_2d(filter = 64, kernel_size = c(3, 3), strides = c(1, 1),
                activation = "relu") %>%
  layer_max_pooling_2d(pool_size = c(2, 2), strides = c(2, 2)) %>%
  layer_flatten() %>%
  layer_dense(2, activation = "softmax")

summary(model)

model %>% compile(
  loss = "categorical_crossentropy",
  optimizer = optimizer_sgd(lr = 0.0001, decay = 1e-6),
  metrics = "accuracy"
)

tensorboard("/data/logs/ships")

#This takes awhile, probably faster on GPUs
ships_fit <- model %>% fit(x = train[[1]], y = train[[2]], epochs = 20, batch_size = 32,
                           validation_split = 0.2,
                           callbacks = callback_tensorboard("/data/logs/ships"))

###### Stopped here

predicted_probs <- model %>%
  predict_proba(test[[1]]) %>%
  cbind(test[[2]])

head(predicted_probs)

model %>% evaluate(test[[1]], test[[2]])

set.seed(1111)
sample_plots <- sample(1:dim(test[[1]])[1], 12) %>%
  map(~ {
    plot_data <- cbind(xy_axis, r = as.vector(t(test[[1]][.x, , , 1])),
                       g = as.vector(t(test[[1]][.x, , , 2])),
                       b = as.vector(t(test[[1]][.x, , , 3])))
    ggplot(plot_data, aes(x, y, fill = rgb(r, g, b))) + guides(fill = FALSE) +
      scale_fill_identity() + theme_void() + geom_raster(hjust = 0, vjust = 0) +
      ggtitle(ifelse(test[[2]][.x, 2], "Ship", "Non-ship")) +
      labs(caption = paste("Ship prob:", round(predicted_probs[.x, 2], 6))) +
      theme(plot.title = element_text(hjust = 0.5))
  })

do.call("grid.arrange", c(sample_plots, ncol = 4, nrow = 3))



