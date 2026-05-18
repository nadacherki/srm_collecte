# Regles ProGuard/R8 pour le build release SRM Collecte.
# Flutter gere son propre code natif ; on protege seulement ce que R8
# pourrait casser via reflexion / plugins.

# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_secure_storage (Keystore)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# location / Bluetooth GNSS
-keep class com.lyokone.location.** { *; }

# sqflite / sqlite3
-keep class com.tekartik.** { *; }
-keep class io.requery.android.database.** { *; }

# Modeles serialises via reflexion (json) : ne pas obfusquer les champs
# annotes si jamais on introduit json_serializable.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Eviter les warnings sur les libs optionnelles
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
