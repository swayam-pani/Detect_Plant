import numpy as np
import tflite_runtime.interpreter as tflite
from PIL import Image

IMG_SIZE = (224, 224)

# Load TFLite model
interpreter = tflite.Interpreter(model_path="assets/plant_model_quantized.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Load labels
with open("labels.txt") as f:
    labels = [line.strip() for line in f.readlines()]

# Load image
img = Image.open("aloe_vera.jpeg").convert("RGB")
img = img.resize(IMG_SIZE)

img_array = np.array(img).astype("float32") / 255.0
img_array = np.expand_dims(img_array, axis=0)

# Run inference
interpreter.set_tensor(input_details[0]['index'], img_array)
interpreter.invoke()

output = interpreter.get_tensor(output_details[0]['index'])[0]

pred_index = np.argmax(output)

print("Prediction:", labels[pred_index])
print("Confidence:", float(output[pred_index]))