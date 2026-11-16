/// Palabra de la letra con el momento en que se canta.
class PalabraLetra {
  /// Crea la palabra.
  const PalabraLetra({
    required this.texto,
    required this.inicio,
    required this.fin,
  });

  /// Crea la palabra desde la respuesta del servidor (tiempos en segundos).
  factory PalabraLetra.desdeJson(Map<String, dynamic> json) => PalabraLetra(
    texto: json['texto'] as String,
    inicio: _tiempo(json['inicio']),
    fin: _tiempo(json['fin']),
  );

  /// Texto de la palabra.
  final String texto;

  /// Momento en que empieza a cantarse.
  final Duration inicio;

  /// Momento en que termina.
  final Duration fin;
}

/// Línea de la letra, con sus palabras.
class LineaLetra {
  /// Crea la línea.
  const LineaLetra({
    required this.inicio,
    required this.fin,
    required this.palabras,
  });

  /// Crea la línea desde la respuesta del servidor.
  factory LineaLetra.desdeJson(Map<String, dynamic> json) => LineaLetra(
    inicio: _tiempo(json['inicio']),
    fin: _tiempo(json['fin']),
    palabras: <PalabraLetra>[
      for (final dynamic palabra in json['palabras'] as List<dynamic>)
        PalabraLetra.desdeJson(palabra as Map<String, dynamic>),
    ],
  );

  /// Inicio de la línea.
  final Duration inicio;

  /// Fin de la línea.
  final Duration fin;

  /// Palabras en el orden en que se cantan.
  final List<PalabraLetra> palabras;

  /// Texto completo de la línea.
  String get texto =>
      palabras.map((PalabraLetra palabra) => palabra.texto).join(' ');
}

/// Letra sincronizada por palabra del Modo Karaoke (Pb-5 y Pb-10), la misma
/// que usa la web.
class Letra {
  /// Crea la letra con sus [lineas].
  const Letra(this.lineas);

  /// Crea la letra desde la respuesta de `GET /jobs/{id}/letra`.
  factory Letra.desdeJson(Map<String, dynamic> json) => Letra(<LineaLetra>[
    for (final dynamic linea in json['lineas'] as List<dynamic>)
      LineaLetra.desdeJson(linea as Map<String, dynamic>),
  ]);

  /// Líneas en el orden de la canción.
  final List<LineaLetra> lineas;

  /// Línea que corresponde a la [posicion] del audio: la primera que todavía
  /// no termina; al final de la canción, la última.
  int indiceLinea(Duration posicion) {
    final int indice = lineas.indexWhere(
      (LineaLetra linea) => posicion < linea.fin,
    );
    return indice == -1 ? lineas.length - 1 : indice;
  }
}

Duration _tiempo(Object? segundos) =>
    Duration(microseconds: ((segundos! as num) * 1000000).round());
