# -*- coding: utf-8 -*-
from logging import getLogger
from pydbm.cnn.convolutional_neural_network import ConvolutionalNeuralNetwork
from pydbm.cnn.layerablecnn.convolution_layer import ConvolutionLayer
import numpy as np
cimport numpy as np
ctypedef np.float64_t DOUBLE_t


class ConvolutionalAutoEncoder(ConvolutionalNeuralNetwork):
    '''
    Convolutional Auto-Encoder which is-a `ConvolutionalNeuralNetwork`.
    
    A stack of Convolutional Auto-Encoder (Masci, J., et al., 2011) 
    forms a convolutional neural network(CNN), which are among the most successful models 
    for supervised image classification.  Each Convolutional Auto-Encoder is trained 
    using conventional on-line gradient descent without additional regularization terms.
    
    In this library, Convolutional Auto-Encoder is also based on Encoder/Decoder scheme.
    The encoder is to the decoder what the Convolution is to the Deconvolution.
    The Deconvolution also called transposed convolutions 
    "work by swapping the forward and backward passes of a convolution." (Dumoulin, V., & Visin, F. 2016, p20.)

    References:
        - Dumoulin, V., & V,kisin, F. (2016). A guide to convolution arithmetic for deep learning. arXiv preprint arXiv:1603.07285.
        - Masci, J., Meier, U., Cireşan, D., & Schmidhuber, J. (2011, June). Stacked convolutional auto-encoders for hierarchical feature extraction. In International Conference on Artificial Neural Networks (pp. 52-59). Springer, Berlin, Heidelberg.

    '''
    # Feature points.
    __feature_points_arr = None

    def __init__(
        self,
        layerable_cnn_list,
        computable_loss,
        opt_params,
        verificatable_result,
        int epochs=100,
        int batch_size=100,
        double learning_rate=1e-05,
        double learning_attenuate_rate=0.1,
        int attenuate_epoch=50,
        double test_size_rate=0.3,
        tol=1e-15,
        tld=100.0,
        save_flag=False,
        pre_learned_path_list=None
    ):
        '''
        Init.
        
        Override.
        
        Args:
            layerable_cnn_list:             The `list` of `ConvolutionLayer`.
            computable_loss:                Loss function.
            opt_params:                     Optimization function.
            verificatable_result:           Verification function.

            epochs:                         Epochs of Mini-batch.
            bath_size:                      Batch size of Mini-batch.
            learning_rate:                  Learning rate.
            learning_attenuate_rate:        Attenuate the `learning_rate` by a factor of this value every `attenuate_epoch`.
            attenuate_epoch:                Attenuate the `learning_rate` by a factor of `learning_attenuate_rate` every `attenuate_epoch`.
                                            Additionally, in relation to regularization,
                                            this class constrains weight matrixes every `attenuate_epoch`.

            test_size_rate:                 Size of Test data set. If this value is `0`, the validation will not be executed.
            tol:                            Tolerance for the optimization.
            tld:                            Tolerance for deviation of loss.
            save_flag:                      If `True`, save `np.ndarray` of inferenced test data in training.
            pre_learned_path_list:          `list` of file path that stores pre-learned parameters.

        '''
        super().__init__(
            layerable_cnn_list=layerable_cnn_list,
            computable_loss=computable_loss,
            opt_params=opt_params,
            verificatable_result=verificatable_result,
            epochs=epochs,
            batch_size=batch_size,
            learning_rate=learning_rate,
            learning_attenuate_rate=learning_attenuate_rate,
            attenuate_epoch=attenuate_epoch,
            test_size_rate=test_size_rate,
            tol=tol,
            tld=tld,
            save_flag=save_flag,
            pre_learned_path_list=pre_learned_path_list
        )
        self.__epochs = epochs
        self.__batch_size = batch_size
        self.opt_params = opt_params

        self.__learning_rate = learning_rate
        self.__learning_attenuate_rate = learning_attenuate_rate
        self.__attenuate_epoch = attenuate_epoch

        self.__test_size_rate = test_size_rate
        self.__tol = tol
        self.__tld = tld

        self.__memory_tuple_list = []
        
        self.__save_flag = save_flag

        logger = getLogger("pydbm")
        self.__logger = logger
        self.__learn_mode = True
        self.__logger.debug("Setup Convolutional Auto-Encoder and the parameters.")

    def forward_propagation(self, np.ndarray[DOUBLE_t, ndim=4] img_arr):
        '''
        Forward propagation in Convolutional Auto-Encoder.
        
        Override.
        
        Args:
            img_arr:    `np.ndarray` of image file array.
        
        Returns:
            Propagated `np.ndarray`.
        '''
        cdef np.ndarray[DOUBLE_t, ndim=2] hidden_activity_arr
        cdef int i = 0

        for i in range(len(self.layerable_cnn_list)):
            try:
                img_arr = self.layerable_cnn_list[i].convolve(img_arr)
                img_arr = self.layerable_cnn_list[i].graph.activation_function.activate(img_arr)
            except:
                self.__logger.debug("Error raised in Convolution layer " + str(i + 1))
                raise

        self.__feature_points_arr = img_arr.copy()

        if self.opt_params.dropout_rate > 0:
            hidden_activity_arr = img_arr.reshape((img_arr.shape[0], -1))
            hidden_activity_arr = self.opt_params.dropout(hidden_activity_arr)
            img_arr = hidden_activity_arr.reshape((
                img_arr.shape[0],
                img_arr.shape[1],
                img_arr.shape[2],
                img_arr.shape[3]
            ))

        layerable_cnn_list = self.layerable_cnn_list[::-1]
        for i in range(len(layerable_cnn_list)):
            try:
                img_arr = layerable_cnn_list[i].graph.activation_function.backward(img_arr)
                img_arr = layerable_cnn_list[i].deconvolve(img_arr)
                img_arr = layerable_cnn_list[i].graph.deactivation_function.activate(img_arr)
            except:
                self.__logger.debug("Error raised in Deconvolution layer " + str(i + 1))
                raise

        return img_arr

    def back_propagation(self, np.ndarray[DOUBLE_t, ndim=4] delta_arr):
        '''
        Back propagation in CNN.
        
        Override.
        
        Args:
            Delta.
        
        Returns.
            Delta.
        '''
        cdef int i = 0        
        for i in range(len(self.layerable_cnn_list)):
            try:
                delta_arr = self.layerable_cnn_list[i].convolve(delta_arr, no_bias_flag=True)
            except:
                self.__logger.debug("Backward raised error in Convolution layer " + str(i + 1))
                raise

        cdef np.ndarray[DOUBLE_t, ndim=2] hidden_activity_arr
        if self.opt_params.dropout_rate > 0:
            hidden_activity_arr = delta_arr.reshape((delta_arr.shape[0], -1))
            hidden_activity_arr = self.opt_params.de_dropout(hidden_activity_arr)
            delta_arr = hidden_activity_arr.reshape((
                delta_arr.shape[0],
                delta_arr.shape[1],
                delta_arr.shape[2],
                delta_arr.shape[3]
            ))

        layerable_cnn_list = self.layerable_cnn_list[::-1]
        for i in range(len(layerable_cnn_list)):
            try:
                delta_arr = layerable_cnn_list[i].back_propagate(delta_arr)
                delta_arr = layerable_cnn_list[i].graph.deactivation_function.forward(delta_arr)
            except:
                self.__logger.debug(
                    "Delta computation raised an error in CNN layer " + str(len(layerable_cnn_list) - i)
                )
                raise

        return delta_arr

    def extract_feature_points_arr(self):
        '''
        Extract feature points.

        Returns:
            `np.ndarray` of feature points in hidden layer
            which means the encoded data.
        '''
        return self.__feature_points_arr
