-- Crear extension si no existe
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabla de perfiles (metadatos del usuario)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  nombre TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de grabaciones (una noche de sueno)
CREATE TABLE IF NOT EXISTS public.grabaciones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  fecha_inicio TIMESTAMPTZ NOT NULL,
  fecha_fin TIMESTAMPTZ,
  duracion_total_minutos INT,
  total_ronquidos INT DEFAULT 0,
  duracion_promedio_s FLOAT,
  duracion_maxima_s FLOAT,
  decibelio_promedio FLOAT,
  decibelio_maximo FLOAT,
  frecuencia_promedio_hz FLOAT,
  audio_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de eventos detectados (ronquidos, pausas, ruidos)
CREATE TABLE IF NOT EXISTS public.eventos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  grabacion_id UUID NOT NULL REFERENCES public.grabaciones ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('ronquido', 'pausa', 'ruido_fuerte')),
  inicio_segundo INT NOT NULL,
  duracion_segundos FLOAT,
  intensidad_db FLOAT,
  frecuencia_hz FLOAT
);

-- Tabla de datos del timeline (para graficos)
CREATE TABLE IF NOT EXISTS public.timeline_data (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  grabacion_id UUID NOT NULL REFERENCES public.grabaciones ON DELETE CASCADE,
  segundo INT NOT NULL,
  nivel_db FLOAT,
  es_ronquido BOOLEAN DEFAULT FALSE
);

-- Activar Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grabaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timeline_data ENABLE ROW LEVEL SECURITY;

-- Politicas para profiles
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Politicas para grabaciones
CREATE POLICY "Users can view own grabaciones" ON public.grabaciones
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own grabaciones" ON public.grabaciones
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own grabaciones" ON public.grabaciones
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own grabaciones" ON public.grabaciones
  FOR DELETE USING (auth.uid() = user_id);

-- Politicas para eventos
CREATE POLICY "Users can view own eventos" ON public.eventos
  FOR SELECT USING (auth.uid() = (
    SELECT user_id FROM public.grabaciones WHERE id = eventos.grabacion_id
  ));

CREATE POLICY "Users can insert own eventos" ON public.eventos
  FOR INSERT WITH CHECK (auth.uid() = (
    SELECT user_id FROM public.grabaciones WHERE id = eventos.grabacion_id
  ));

CREATE POLICY "Users can delete own eventos" ON public.eventos
  FOR DELETE USING (auth.uid() = (
    SELECT user_id FROM public.grabaciones WHERE id = eventos.grabacion_id
  ));

-- Politicas para timeline_data
CREATE POLICY "Users can view own timeline" ON public.timeline_data
  FOR SELECT USING (auth.uid() = (
    SELECT user_id FROM public.grabaciones WHERE id = timeline_data.grabacion_id
  ));

CREATE POLICY "Users can insert own timeline" ON public.timeline_data
  FOR INSERT WITH CHECK (auth.uid() = (
    SELECT user_id FROM public.grabaciones WHERE id = timeline_data.grabacion_id
  ));

CREATE POLICY "Users can delete own timeline" ON public.timeline_data
  FOR DELETE USING (auth.uid() = (
    SELECT user_id FROM public.grabaciones WHERE id = timeline_data.grabacion_id
  ));

-- Crear funciones para manejo de perfiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para crear perfil al registrarse un usuario
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Crear Storage bucket para audios
INSERT INTO storage.buckets (id, name, public)
VALUES ('audios-nocturnos', 'audios-nocturnos', FALSE)
ON CONFLICT (id) DO NOTHING;

-- Politicas de Storage
CREATE POLICY "Users can upload own audios" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'audios-nocturnos' AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own audios" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'audios-nocturnos' AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own audios" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'audios-nocturnos' AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Indices para performance
CREATE INDEX IF NOT EXISTS idx_grabaciones_user_id ON public.grabaciones(user_id);
CREATE INDEX IF NOT EXISTS idx_grabaciones_fecha ON public.grabaciones(fecha_inicio DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_grabacion ON public.eventos(grabacion_id);
CREATE INDEX IF NOT EXISTS idx_eventos_tipo ON public.eventos(tipo);
CREATE INDEX IF NOT EXISTS idx_timeline_grabacion ON public.timeline_data(grabacion_id);
