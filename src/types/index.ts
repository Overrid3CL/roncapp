export interface UserProfile {
  id: string;
  email: string;
  nombre?: string;
  created_at: string;
}

export interface Estadisticas {
  total_ronquidos: number;
  duracion_promedio_s: number;
  duracion_maxima_s: number;
  decibelio_promedio: number;
  decibelio_maximo: number;
  frecuencia_promedio_hz: number;
}

export interface Evento {
  id?: string;
  grabacion_id: string;
  tipo: 'ronquido' | 'pausa' | 'ruido_fuerte';
  inicio_segundo: number;
  duracion_segundos: number;
  intensidad_db: number;
  frecuencia_hz: number;
}

export interface TimelinePoint {
  id?: string;
  grabacion_id: string;
  segundo: number;
  nivel_db: number;
  es_ronquido: boolean;
}

export interface GrabacionNoche {
  id?: string;
  user_id: string;
  fecha_inicio: string;
  fecha_fin?: string;
  duracion_total_minutos?: number;
  total_ronquidos: number;
  duracion_promedio_s?: number;
  duracion_maxima_s?: number;
  decibelio_promedio?: number;
  decibelio_maximo?: number;
  frecuencia_promedio_hz?: number;
  audio_url?: string;
  created_at?: string;
}
