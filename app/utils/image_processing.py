import cv2
import numpy as np

def load_image(image_path):
    """
    Loads image from disk
    """
    image = cv2.imread(image_path)
    return image


def to_grayscale(image):
    """
    Converts BGR image to grayscale
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return gray

def calculate_brightness(gray_image):  #Brightness tells us how dark the sky is.
    """
    Average brightness of image
    """
    return float(np.mean(gray_image))

def calculate_edge_density(gray_image):    #Cloud-heavy skies have more edges.
    edges = cv2.Canny(gray_image, 50, 150)
    edge_pixels = np.sum(edges > 0)
    total_pixels = edges.size
    return float(edge_pixels / total_pixels)

def calculate_entropy(gray_image):   #Entropy = how chaotic the image looks.
    histogram = cv2.calcHist([gray_image], [0], None, [256], [0, 256])
    histogram = histogram / histogram.sum()
    histogram = histogram[histogram > 0]

    entropy = -np.sum(histogram * np.log2(histogram))
    return float(entropy)


def extract_features(image_path):
    image = load_image(image_path)
    gray = to_grayscale(image)

    features = {
        "brightness": calculate_brightness(gray),
        "edge_density": calculate_edge_density(gray),
        "entropy": calculate_entropy(gray)
    }

    return features
