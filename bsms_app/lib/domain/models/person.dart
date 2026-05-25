class Person {
  final String id;
  final String name;
  final int age;
  final String notes;

  const Person({
    required this.id,
    required this.name,
    required this.age,
    this.notes = '',
  });

  Person copyWith({String? name, int? age, String? notes}) => Person(
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'notes': notes,
      };

  factory Person.fromMap(Map<String, dynamic> map) => Person(
        id: map['id'] as String,
        name: map['name'] as String,
        age: map['age'] as int,
        notes: (map['notes'] as String?) ?? '',
      );
}
