# RONQUIDS — Plan de Aplicacion

## 1. Vision

Una app movil/web simple que grabe el audio ambiental durante la noche,
detecte automaticamente ronquidos, ruidos fuertes o apneas,
y genere un reporte matutino con estadisticas y graficos.

### Casos de uso principales
- Saber si ronco y con que intensidad/frecuencia
- Detectar posibles pausas respiratorias (apneas)
- Compartir datos con un medico
- Monitorear si un tratamiento funciona

---

## 2. Alcance (MVP)

### INCLUIDO (v1)
- Grabacion continua durante la noche con deteccion inteligente
  (solo guarda los fragmentos con sonido, no horas de silencio)
- Algoritmo basico de deteccion de ronquidos usando analisis de frecuencia
- Dashboard simple con estadisticas y grafico de timeline
- Historial de grabaciones anteriores con filtrado por fecha
- Autenticacion de usuarios (Supabase Auth): email + magic link
- Persistencia en la nube (Supabase Database): datos sincronizados entre dispositivos
- Almacenamiento de audios en Supabase Storage (opcional, el usuario decide)
- Modo offline con sync diferida (funciona sin internet y sube cuando hay conexion)

### EXCLUIDO (para futuras versiones)
- Deteccion medica certificada de apnea del sueno
- Integracion con wearables
- Alarmas inteligentes
- Diagnostico medico

---

## 3. Flujo de usuario

### Flujo de primera vez
```
USUARIO
   |
   v
[ Pantalla de bienvenida ]
  - Breve explicacion de la app
  - "Comenzar"
   |
   v
[ Login / Registro (Supabase) ]
  - Email + magic link (sin password)
  - O anonimo (puede vincular email despues)
   |
   v
[ Pantalla principal ]
  - Boton "Iniciar grabacion"
  - Calendario con noches registradas
  - Avatar + nombre del usuario
```

### Flujo normal
```
[ Pantalla principal ]
   |
   v
[ Pantalla de grabacion ]
  - Microfono activo con visualizacion de decibelios
  - Temporizador de inicio
  - "Finalizar al despertar"
   |
   v
( Usuario duerme, app graba en segundo plano )
   |
   v
[ Pantalla de analisis (mañana) ]
  - Procesando audio localmente...
  - Resultados: eventos, grafico, score
   |
   v
[ Sincronizacion con Supabase ]
  - Si hay internet: sube datos y audio
  - Si no hay internet: guarda en cola local
   |
   v
[ Historial - lista de noches grabadas ]
  - Datos cargados desde Supabase (o local si offline)
```

---

## 4. Arquitectura

### Tecnologia recomendada: React Native + Expo

---

### Que es Expo

Expo es un framework y una plataforma que simplifica el desarrollo de apps con React Native. No es un reemplazo de React Native, sino un conjunto de herramientas que corre encima de el.

**Como funciona:**
- Escribis codigo en React Native (JavaScript/TypeScript)
- Expo te da bibliotecas listas para usar (camara, microfono, notificaciones, sensores) con una API unificada
- Ejecutas la app con la app gratuita `Expo Go` en tu celular, sin necesidad de compilar nada
- Cuando estas listo, podes compilar a app nativa (APK/IPA) con `eas build` en la nube de Expo, sin tener Android Studio ni Xcode instalados

**Ventajas para esta app:**
- No necesitas Mac para compilar para iOS (Expo lo hace en su nube)
- `expo-av` maneja grabacion de audio en pocos pasos
- Expo Router simplifica la navegacion entre pantallas
- Facil de compartir: generas un QR y cualquiera prueba la app

**Limitaciones:**
- Algunas librerias nativas muy especificas requieren "eject" (salir de Expo)
- El tamano de la app base es mayor que React Native puro
- Para audio en background prolongado puede requerir configuracion extra

**En resumen:** Expo te permite llegar mas rapido a un MVP funcional en celulares reales, sin dolores de configuracion nativa.

---

### Stack sugerido (React Native + Expo)

| Capa | Tecnologia |
|------|------------|
| Frontend | React Native (Expo SDK 52) |
| Navegacion | Expo Router |
| Audio | expo-av (grabacion) + Web Audio API (analisis) |
| Estado / Estado global | Zustand |
| Base de datos / Sync | Supabase (PostgreSQL + Realtime) |
| Autenticacion | Supabase Auth (email, magic link, OAuth) |
| Almacenamiento de archivos | Supabase Storage (audios) |
| Graficos | react-native-svg o Victory Native |
| Procesamiento | Local en app (FFT con dsp.js o equivalente) |
| Backend propio | Ninguno (usamos Supabase como BaaS) |

---

## 5. Integracion con Supabase

Supabase actua como backend-as-a-service. Proporciona base de datos, autenticacion, almacenamiento de archivos y sync en tiempo real, sin necesidad de escribir un servidor propio.

### Tablas en Supabase (PostgreSQL)

```sql
-- Usuarios: manejado por Supabase Auth (tabla auth.users)
-- Solo agregamos metadatos:

create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  nombre text,
  created_at timestamptz default now()
);

-- Grabaciones: una fila por noche
create table public.grabaciones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade not null,
  fecha_inicio timestamptz not null,
  fecha_fin timestamptz,
  duracion_total_minutos int,
  total_ronquidos int default 0,
  duracion_promedio_s float,
  duracion_maxima_s float,
  decibelio_promedio float,
  decibelio_maximo float,
  frecuencia_promedio_hz float,
  audio_url text, -- link a Supabase Storage (opcional)
  created_at timestamptz default now()
);

-- Eventos: cada ronquido/ruido detectado
create table public.eventos (
  id uuid primary key default gen_random_uuid(),
  grabacion_id uuid references public.grabaciones on delete cascade not null,
  tipo text check (tipo in ('ronquido', 'pausa', 'ruido_fuerte')),
  inicio_segundo int not null,
  duracion_segundos float,
  intensidad_db float,
  frecuencia_hz float
);

-- Timeline: datos para el grafico (comprimidos, un punto cada X segundos)
create table public.timeline_data (
  id uuid primary key default gen_random_uuid(),
  grabacion_id uuid references public.grabaciones on delete cascade not null,
  segundo int not null,
  nivel_db float,
  es_ronquido boolean default false
);

-- Row Level Security (RLS): cada usuario solo ve sus propios datos
alter table public.grabaciones enable row level security;
alter table public.eventos enable row level security;
alter table public.timeline_data enable row level security;
alter table public.profiles enable row level security;

create policy "Users can only access their own grabaciones"
  on public.grabaciones for all
  using (auth.uid() = user_id);

create policy "Users can only access their own eventos"
  on public.eventos for all
  using (auth.uid() = (select user_id from public.grabaciones where id = grabacion_id));
```

### Supabase Storage (audios)

- Bucket `audios-nocturnos` con acceso privado
- Ruta: `{user_id}/{grabacion_id}.opus`
- Solo subir si el usuario activa "Guardar audio completo"
- Por defecto solo se guardan metadatos (eventos, timeline), no el audio raw

### Cliente en la app

```typescript
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  process.env.EXPO_PUBLIC_SUPABASE_URL!,
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!
);

// Uso tipico:
// const { data, error } = await supabase.auth.signInWithOtp({ email });
// const { data } = await supabase.from('grabaciones').select('*');
// const { data } = await supabase.storage.from('audios-nocturnos').upload(path, file);
```

### Funcionalidades que usan Supabase

| Funcionalidad | Servicio Supabase | Justificacion |
|---------------|-------------------|---------------|
| Login / registro | Supabase Auth | Sin passwords, magic link o OAuth. El usuario puede usar la app desde cualquier dispositivo. |
| Historial de noches | Supabase Database | Persistencia en la nube. Si cambia de celular, no pierde datos. |
| Detalle de una noche | Supabase Database | Eventos, timeline y estadisticas guardados en PostgreSQL. |
| Compartir con medico | Supabase Database | Generar un link temporal o exportar datos del usuario. |
| Backup de audios | Supabase Storage | Opcional. Solo si el usuario quiere conservar la grabacion completa. |
| Offline-first | AsyncStorage + Sync | Los datos se guardan local primero, luego sync con Supabase cuando hay red. |

### Que NO usa Supabase (proceso local)

- **Grabacion de audio**: manejado por expo-av directamente en el dispositivo
- **Analisis FFT y deteccion de ronquidos**: procesado localmente, nunca se sube audio raw a analizar
- **Visualizacion de waveform**: render local con los datos del microfono
- **Dashboard con estadisticas**: calculadas localmente al mostrar

---

## 6. Deteccion de ronquidos (algoritmo v1)

No necesitamos IA compleja. Un analisis de frecuencia basico funciona:

1. **Ventana deslizante**: analizar el audio cada 0.5 segundos
2. **FFT (Transformada Rapida de Fourier)**: obtener frecuencias dominantes
3. **Rango de ronquido**: tipicamente 20-300 Hz, con picos entre 100-200 Hz
4. **Umbral de amplitud**: si la energia en ese rango supera X dB, marcar como "posible ronquido"
5. **Duracion minima**: un ronquido dura tipicamente 0.5-2 segundos
6. **Patron**: los ronquidos vienen en secuencias (no son eventos aislados)

### Pseudocodigo del detector
```javascript
function detectarRonquido(bufferAudio) {
  const fft = calcularFFT(bufferAudio);
  const frecuenciasBajas = extraerBanda(fft, 20, 300); // Hz
  const energia = calcularEnergia(frecuenciasBajas);
  const dB = convertirADecibelios(energia);

  if (dB > UMBRAL_RONQUIDO && duracion > 0.5s) {
    return {
      tipo: "ronquido",
      inicio: timestamp,
      duracion: segundos,
      intensidad: dB,
      frecuenciaPrincipal: freqMax
    };
  }
}
```

### Umbrales configurables (ajustables por usuario)
- Sensibilidad: Baja / Media / Alta
- Umbral de dB para considerar ruido (default: 40 dB)
- Frecuencia minima de ronquido: 80 Hz

---

## 6. Estructura de datos

### Objeto de grabacion por noche
```typescript
interface GrabacionNoche {
  id: string;              // UUID
  userId: string;          // UUID de Supabase Auth
  fechaInicio: Date;       // cuando presiono "Iniciar"
  fechaFin: Date;          // cuando presiono "Terminar"
  duracionTotalMinutos: number;
  audioPath?: string;      // ruta local al archivo WAV/OPUS
  audioUrl?: string;       // URL de Supabase Storage (si subio)
  syncStatus: "synced" | "pending" | "error"; // estado de sync con Supabase

  // Resultados del analisis
  estadisticas: {
    totalRonquidos: number;
    duracionPromedioS: number;
    duracionMaximaS: number;
    decibelioPromedio: number;
    decibelioMaximo: number;
    frecuenciaPromedioHz: number;
  };

  // Eventos detectados
  eventos: Array<{
    tipo: "ronquido" | "pausa" | "ruido_fuerte";
    inicioSegundo: number;   // desde el inicio de la grabacion
    duracionSegundos: number;
    intensidadDb: number;
    frecuenciaHz: number;
  }>;

  // Para el grafico de linea de tiempo
  timelineData: Array<{
    segundo: number;
    nivelDb: number;
    esRonquido: boolean;
  }>;
}
```

### Objeto de usuario (Supabase Auth)
```typescript
interface UserProfile {
  id: string;              // UUID de auth.users
  email: string;
  nombre?: string;
  createdAt: Date;
}
```

---

## 7. Diseño de pantallas

### Pantalla 1: Inicio / Dashboard
```
        LUN 18 MAY
     [calendario mini]

  ULTIMA NOCHE
  47 ronquidos detectados
  Duracion promedio: 2.3s
  Pico maximo: 68 dB
  [Ver detalle >]

  [    INICIAR GRABACION    ]
```

### Pantalla 2: Grabando
```
      Grabando...
    [ waveform animado ]

      02:34:12
      68 dB

  [   Finalizar y Analizar   ]

  (la pantalla se mantiene prendida automaticamente)
```

### Pantalla 3: Resultados
```
      RESUMEN DE LA NOCHE
      18 de mayo, 2025

  [ GRAFICO DE LINEA DE TIEMPO ]
  (barras coloreadas: ronquido=rojo, silencio=gris)

  47    2.3s      68dB      45
 ronq   prom      max     min

  [ LISTA DE EVENTOS DESTACADOS ]
  - 02:14 AM: ronquido 6s, 65 dB
  - 03:41 AM: ronquido 4s, 68 dB
  - 05:02 AM: ronquido 5s, 62 dB

  [    Guardar    ] [    Descartar    ]
```

### Pantalla 4: Historial
```
      HISTORIAL

  [ Lun 18 ]  47 ronquidos  [>]
  [ Dom 17 ]  38 ronquidos  [>]
  [ Sab 16 ]  52 ronquidos  [>]
  [ Vie 15 ]  29 ronquidos  [>]

  (toca una noche para ver detalle)
```

---

## 8. Consideraciones tecnicas

### Bateria
- La grabacion consume bateria. Recomendaciones:
  - Mantener pantalla apagada (usar wake lock solo para evitar suspension)
  - Grabar en mono, no estereo (menos datos)
  - Sample rate bajo: 16 kHz es suficiente para ronquidos
  - Usar formato comprimido (OPUS) en vez de WAV raw
  - Mostrar alerta: "Conecta el cargador"

### Privacidad y datos
- Todo el audio se procesa LOCALMENTE (FFT y deteccion en el celular)
- Supabase solo recibe metadatos: estadisticas, eventos, timeline comprimido
- Los audios raw NO se suben por defecto (el usuario puede activarlo opcionalmente)
- Row Level Security (RLS) en Supabase: cada usuario solo accede a sus propios datos
- El usuario puede borrar datos local y de la nube desde ajustes
- Opcion "Solo local": desactivar Supabase y usar solo AsyncStorage

### Permisos necesarios
- Microfono (obvio)
- Notificaciones (para "grabacion activa" en background)
- Wake lock / Prevent sleep (en web: Screen Wake Lock API)
- Internet (solo para sync con Supabase)

### Compresion de audio
- Grabar en formato comprimido desde el inicio
- OPUS a 16kbps en mono = ~7 MB por noche
- WAV sin comprimir = ~550 MB por noche (no viable)
- Timeline se comprime: un punto cada 5-10 segundos en vez de continuo

### Offline-first
- AsyncStorage guarda todo localmente primero
- Cuando hay internet, `syncManager.ts` sube a Supabase en segundo plano
- Si el usuario esta offline, la app funciona 100%
- Al reconectar, se sincroniza automaticamente
- Conflictos: gana el dato mas reciente (timestamp)

---

## 9. Estructura de carpetas del proyecto

```
ronquidos-app/
├── app/                          # Expo Router
│   ├── index.tsx                 # Pantalla principal (dashboard)
│   ├── grabar.tsx                # Pantalla de grabacion
│   ├── resultado/[id].tsx        # Resultados de una noche
│   ├── historial.tsx             # Lista de noches grabadas
│   ├── ajustes.tsx               # Configuracion + perfil
│   ├── login.tsx                 # Login / registro con Supabase
│   └── _layout.tsx               # Layout raiz (auth provider)
│
├── src/
│   ├── lib/
│   │   └── supabase.ts           # Cliente de Supabase
│   │
│   ├── audio/
│   │   ├── recorder.ts           # Logica de grabacion (expo-av)
│   │   └── analyzer.ts           # FFT + deteccion de ronquidos
│   │
│   ├── storage/
│   │   ├── localStore.ts         # AsyncStorage (offline-first)
│   │   ├── supabaseStore.ts      # CRUD en Supabase (sync)
│   │   └── syncManager.ts        # Cola de sync offline -> online
│   │
│   ├── components/
│   │   ├── Waveform.tsx          # Visualizacion de onda de audio
│   │   ├── TimelineChart.tsx     # Grafico de linea de tiempo
│   │   ├── StatCard.tsx          # Tarjetas de estadisticas
│   │   └── RecordingButton.tsx   # Boton grande de grabar
│   │
│   ├── hooks/
│   │   ├── useAudioRecorder.ts   # Hook de grabacion
│   │   ├── useSnoreDetector.ts   # Hook de deteccion
│   │   ├── useAuth.ts            # Hook de autenticacion (Supabase)
│   │   ├── useGrabaciones.ts     # Hook de CRUD de noches
│   │   └── useSync.ts            # Hook de sync offline/online
│   │
│   └── types/
│       └── index.ts              # Interfaces TypeScript
│
├── assets/
│   ├── icon.png
│   └── splash.png
│
├── .env                          # EXPO_PUBLIC_SUPABASE_URL, EXPO_PUBLIC_SUPABASE_ANON_KEY
├── app.json                      # Config de Expo
├── package.json
└── README.md
```

---

## 10. Roadmap

| Fase | Tiempo estimado | Que incluye |
|------|-----------------|-------------|
| **Fase 0: Setup** | 0.5 dias | Proyecto Expo creado, Supabase configurado (proyecto nuevo, tablas, RLS, bucket de storage), variables de entorno listas. |
| **Fase 1: Auth** | 0.5-1 dia | Login/registro con Supabase Auth (email + magic link), proteccion de rutas, pantalla de perfil. |
| **Fase 2: Grabacion local** | 1-2 dias | Grabar audio con expo-av, visualizar waveform, guardar archivo local. |
| **Fase 3: Deteccion** | 1-2 dias | FFT basico, deteccion de ronquidos, pantalla de resultados con estadisticas. |
| **Fase 4: Sync con Supabase** | 1-2 dias | Guardar metadatos en Supabase, sync offline-first, cargar historial desde la nube. |
| **Fase 5: Pulido** | 1 semana | Grafico de timeline, ajustes de sensibilidad, exportar datos, icono, splash, onboarding. |
| **Fase 6: Nativo** | +2 semanas | Si es necesario, salir de Expo para audio en background real en iOS/Android puro. |

---

## 11. Ideas de nombre

- **Ronquids** (ingles: "snores" + spanglish)
- **NoctuSonido**
- **RoncoTrack**
- **SueñoMonitor**
- **DormiLog**

---

## 12. Notas para el desarrollador

### Recursos utiles
- Expo AV: https://docs.expo.dev/versions/latest/sdk/av/
- Web Audio API FFT: https://developer.mozilla.org/en-US/docs/Web/API/AnalyserNode
- Patrones de ronquido (paper): frecuencia fundamental tipica 100-200 Hz
  
### Limitaciones conocidas de la version web/PWA
- iOS Safari: no permite audio en background cuando la pantalla se apaga
  (Workaround: usar Screen Wake Lock para mantener la pantalla prendida,
   o usar React Native para produccion)
- Chrome Android: si funciona audio en background con Service Workers

### Para produccion (React Native)
- Usar `react-native-background-timer` o `react-native-track-player`
  para mantener la app viva toda la noche
- Grabar con `react-native-audio-recorder-player` para mejor control
  de formato y calidad

---

*Plan creado el 18 de mayo de 2025.*
*Este es un MVP deliberadamente simple. La deteccion de ronquidos*
*es heuristica, no medica. No diagnostica apnea del sueno.*
