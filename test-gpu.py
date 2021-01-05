#import tensorflow as tf
#print("GPU Available:", tf.test.is_gpu_available())
import torch
print("Torch version: {} Is GPU Available?: {}".format(torch.__version__,torch.cuda.is_available()))

