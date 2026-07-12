class TechnicianCustodyModel {
  final String id;
  final String technicianId;
  final String? productId;
  final String productName;
  final int quantityReceived;
  final int quantityUsed;
  final int quantityReturned;
  final String? maintenanceId;
  final String? notes;
  final int receivedAt;
  final int? returnedAt;
  final int createdAt;

  // Optional join field
  final String? technicianName;

  const TechnicianCustodyModel({
    required this.id,
    required this.technicianId,
    this.productId,
    required this.productName,
    this.quantityReceived = 0,
    this.quantityUsed = 0,
    this.quantityReturned = 0,
    this.maintenanceId,
    this.notes,
    required this.receivedAt,
    this.returnedAt,
    required this.createdAt,
    this.technicianName,
  });

  int get balance => quantityReceived - quantityUsed - quantityReturned;

  factory TechnicianCustodyModel.fromMap(Map<String, dynamic> map) {
    return TechnicianCustodyModel(
      id: map['id'] as String,
      technicianId: map['technician_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      quantityReceived: map['quantity_received'] as int? ?? 0,
      quantityUsed: map['quantity_used'] as int? ?? 0,
      quantityReturned: map['quantity_returned'] as int? ?? 0,
      maintenanceId: map['maintenance_id'] as String?,
      notes: map['notes'] as String?,
      receivedAt: map['received_at'] as int,
      returnedAt: map['returned_at'] as int?,
      createdAt: map['created_at'] as int,
      technicianName: map['technician_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'technician_id': technicianId,
        'product_id': productId,
        'product_name': productName,
        'quantity_received': quantityReceived,
        'quantity_used': quantityUsed,
        'quantity_returned': quantityReturned,
        'maintenance_id': maintenanceId,
        'notes': notes,
        'received_at': receivedAt,
        'returned_at': returnedAt,
        'created_at': createdAt,
      };

  TechnicianCustodyModel copyWith({
    String? id,
    String? technicianId,
    String? productId,
    String? productName,
    int? quantityReceived,
    int? quantityUsed,
    int? quantityReturned,
    String? maintenanceId,
    String? notes,
    int? receivedAt,
    int? returnedAt,
    int? createdAt,
    String? technicianName,
  }) {
    return TechnicianCustodyModel(
      id: id ?? this.id,
      technicianId: technicianId ?? this.technicianId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      quantityUsed: quantityUsed ?? this.quantityUsed,
      quantityReturned: quantityReturned ?? this.quantityReturned,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      notes: notes ?? this.notes,
      receivedAt: receivedAt ?? this.receivedAt,
      returnedAt: returnedAt ?? this.returnedAt,
      createdAt: createdAt ?? this.createdAt,
      technicianName: technicianName ?? this.technicianName,
    );
  }
}
