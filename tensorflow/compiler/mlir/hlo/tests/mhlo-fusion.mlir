// RUN: mlir-hlo-opt %s -mhlo-fusion -split-input-file | FileCheck %s

// CHECK-LABEL: func @multi_outputs_same
func @multi_outputs_same(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>) -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = "mhlo.add"(%arg0, %arg1) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  %1 = "mhlo.subtract"(%arg0, %0) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  %2 = "mhlo.add"(%1, %1) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  // CHECK: %[[RET:.*]]:2 = "mhlo.fusion"
  // CHECK-NEXT: mhlo.add
  // CHECK-NEXT: mhlo.subtract
  // CHECK-NEXT: mhlo.add
  // CHECK-NEXT: mhlo.return
  return %1, %2 : tensor<?x?xf32>, tensor<?x?xf32>
}

// -----

// CHECK-LABEL: func @multi_outputs_same_2
func @multi_outputs_same_2(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>) -> (tensor<?x?xf32>, tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = "mhlo.abs"(%arg0) : (tensor<?x?xf32>) -> tensor<?x?xf32>
  %1 = "mhlo.abs"(%arg1) : (tensor<?x?xf32>) -> tensor<?x?xf32>
  %2 = "mhlo.add"(%0, %1) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  %3 = "mhlo.abs"(%0) : (tensor<?x?xf32>) -> tensor<?x?xf32>
  %4 = "mhlo.abs"(%1) : (tensor<?x?xf32>) -> tensor<?x?xf32>
  // CHECK: %[[RET:.*]]:3 = "mhlo.fusion"
  // CHECK-NEXT: mhlo.abs
  // CHECK-NEXT: mhlo.abs
  // CHECK-NEXT: mhlo.add
  // CHECK-NEXT: mhlo.abs
  // CHECK-NEXT: mhlo.abs
  // CHECK-NEXT: mhlo.return
  return %2, %3, %4 : tensor<?x?xf32>, tensor<?x?xf32>, tensor<?x?xf32>
}

// -----

// CHECK-LABEL: func @multi_outputs_not_sure_same
func @multi_outputs_not_sure_same(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>) -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = "mhlo.add"(%arg0, %arg0) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  // CHECK-NOT: mhlo.fusion
  %1 = "mhlo.subtract"(%arg1, %arg1) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}

// -----

// CHECK-LABEL: func @reduce
func @reduce(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>) -> (tensor<?x?xf32>, tensor<?xf32>) {
  %0 = "mhlo.add"(%arg0, %arg1) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  %1 = "mhlo.subtract"(%arg0, %0) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  // CHECK: %[[RET0:.*]] = "mhlo.fusion"
  // CHECK-NEXT: mhlo.add
  // CHECK-NEXT: mhlo.subtract
  // CHECK-NEXT: mhlo.return
  // Currently we do not support fuse arguments and ops without direct producer-consumer
  // relationship. Thus Reduce Op should not be fused with above two ops.

  %2 = mhlo.constant dense<0.000000e+00> : tensor<f32>
  %3 = "mhlo.reduce"(%arg0, %2) ( {
  ^bb0(%arg2: tensor<f32>, %arg3: tensor<f32>):
    %4 = "mhlo.add"(%arg2, %arg3) : (tensor<f32>, tensor<f32>) -> tensor<f32>
    "mhlo.return"(%4) : (tensor<f32>) -> ()
  }) {dimensions = dense<[1]> : tensor<1xi64>} : (tensor<?x?xf32>, tensor<f32>) -> tensor<?xf32>
  %4 = "mhlo.add"(%3, %3) : (tensor<?xf32>, tensor<?xf32>) -> tensor<?xf32>
  // Above two ops should not be fused since reduce op can not be
  // fused with its consumer.
  // CHECK-NOT: mhlo.fusion

  return %1, %4 : tensor<?x?xf32>, tensor<?xf32>
}

// -----

// CHECK-LABEL: func @reduce_2
func @reduce_2(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>) -> (tensor<?x?xf32>, tensor<?xf32>) {
  %0 = "mhlo.add"(%arg0, %arg1) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>
  %1 = "mhlo.subtract"(%arg0, %0) : (tensor<?x?xf32>, tensor<?x?xf32>) -> tensor<?x?xf32>

  %2 = mhlo.constant dense<0.000000e+00> : tensor<f32>
  %3 = "mhlo.reduce"(%1, %2) ( {
  ^bb0(%arg2: tensor<f32>, %arg3: tensor<f32>):
    %4 = "mhlo.add"(%arg2, %arg3) : (tensor<f32>, tensor<f32>) -> tensor<f32>
    "mhlo.return"(%4) : (tensor<f32>) -> ()
  }) {dimensions = dense<[1]> : tensor<1xi64>} : (tensor<?x?xf32>, tensor<f32>) -> tensor<?xf32>
  // CHECK: %[[RET0:.*]]:2 = "mhlo.fusion"
  // CHECK-NEXT: mhlo.add
  // CHECK-NEXT: mhlo.subtract
  // CHECK-NEXT: mhlo.constant
  // CHECK-NEXT: mhlo.reduce
  // CHECK: mhlo.return

  // Following op should not be fused with the above ops since reduce op can not be
  // fused with its consumer.
  // CHECK-NOT: mhlo.fusion
  %4 = "mhlo.add"(%3, %3) : (tensor<?xf32>, tensor<?xf32>) -> tensor<?xf32>
  return %1, %4 : tensor<?x?xf32>, tensor<?xf32>
}
