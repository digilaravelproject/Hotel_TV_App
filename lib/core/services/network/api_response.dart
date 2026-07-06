class ApiResponse<T> {
    final bool success;       
    final String message;      
    final T? data;             
    final int? code;           
    final dynamic error;       

    ApiResponse({
        required this.success,
        required this.message,
        this.data,
        this.code,
        this.error
    });

    // Success factory
    factory ApiResponse.success(T data, {String message = "Success", int? code}) {
        return ApiResponse(success: true, message: message, data: data, code: code, error: null);
    }

    // Error factory
    factory ApiResponse.error(String message, {int? code, dynamic error}) {
        return ApiResponse(success: false, message: message, data: null, code: code, error: error);
    }

    // From JSON
    factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
        return ApiResponse(
            success: json['success'] ?? false,
            message: json['message'] ?? '',
            data: json['data'] != null ? fromJsonT(json['data']) : null,
            code: json['code'],
            error: json['error']
        );
    }

    // To JSON
    Map<String, dynamic> toJson() {
        return {
            'success': success,
            'message': message,
            'data': data,
            'code': code,
            'error': error
        };
    }
}
