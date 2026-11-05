import type { Stream } from 'stremio-addon-sdk';
import type { ResolvedStream } from '../types/index.js';

const labels = {
  'tr-dub': 'Türkçe Dublaj',
  'tr-sub': 'Türkçe Altyazı',
  original: 'Orijinal Dil',
  multi: 'Çoklu Ses',
  unknown: 'Bilinmeyen Dil',
};

function getMediaFlowUrl(): string | undefined {
  const value = process.env.MEDIAFLOW_URL?.trim();
  return value ? value.replace(/\/+$/, '') : undefined;
}

function getMediaFlowPassword(): string | undefined {
  const value = process.env.MEDIAFLOW_PASSWORD?.trim();
  return value || undefined;
}

export function mapStream(stream: ResolvedStream): Stream {
  const isDub = stream.language === 'tr-dub';
  const isSub = stream.language === 'tr-sub';

  const langLabel = isDub
    ? 'Türkçe Dublaj'
    : isSub
      ? 'Türkçe Altyazı'
      : (labels[stream.language] ?? 'Türkçe');

  const badge = isDub
    ? '🇹🇷 TR Dublaj'
    : isSub
      ? '💬 TR Altyazı'
      : '🇹🇷 TR Stream';

  let filename = 'video';

  try {
    filename = new URL(stream.url).pathname.split('/').pop() ?? 'video';
  } catch {
    // URL adi formatdadirsa default filename istifadə olunur
  }

  let playUrl = stream.url;

  const referer =
    stream.headers?.referer ||
    stream.headers?.Referer;

  const origin =
    stream.headers?.origin ||
    stream.headers?.Origin;

  const userAgent =
    stream.headers?.['user-agent'] ||
    stream.headers?.['User-Agent'] ||
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36';

  const sp =
    stream.headers?.['x-sp-key'] ||
    stream.headers?.['x-sp'] ||
    stream.headers?.['X-Sp'];

  const isProxied = Boolean(referer || origin);
  const mediaflowUrl = getMediaFlowUrl();
  const mediaflowPassword = getMediaFlowPassword();

  if (isProxied && mediaflowUrl && mediaflowPassword) {
    const params = new URLSearchParams();

    params.set('d', stream.url);
    params.set('api_password', mediaflowPassword);
    params.set('h_user-agent', userAgent);

    if (referer) {
      params.set('h_referer', referer);
    }

    if (origin) {
      params.set('h_origin', origin);
    }

    if (sp) {
      params.set('sp', sp);
    }

    if (isDub) {
      params.set('youtubedubbing', 'true');
    }

    playUrl =
      `${mediaflowUrl}/proxy/hls/manifest.m3u8?${params.toString()}`;
  } else if (isProxied) {
    // MediaFlow URL hazır deyilsə, daxili HLS proxy ehtiyat variantıdır
    const params = new URLSearchParams({
      url: stream.url,
    });

    if (referer) {
      params.set('referer', referer);
    }

    if (origin) {
      params.set('origin', origin);
    }

    if (sp) {
      params.set('sp', sp);
    }

    if (isDub) {
      params.set('audio', 'tr');
    }

    if (isSub) {
      params.set('audio', 'orig');
    }

    const publicBase =
      process.env.PUBLIC_BASE_URL?.replace(/\/+$/, '') ||
      `http://${process.env.PUBLIC_HOST || '127.0.0.1'}:7000`;

    playUrl =
      `${publicBase}/proxy/hls/stream.m3u8?${params.toString()}`;
  }

  const isMediaFlow = playUrl.includes('/proxy/hls/manifest.m3u8');

  return {
    url: playUrl,
    name: `${badge}\n${stream.quality}`,
    title:
      `${stream.providerId.toUpperCase()} • ${stream.quality}\n` +
      `${langLabel} (${stream.format})\n` +
      `${stream.sourceLabel}`,
    ...(stream.subtitles?.length
      ? { subtitles: stream.subtitles }
      : {}),
    behaviorHints: {
      filename: isMediaFlow || isProxied ? 'manifest.m3u8' : filename,
      ...(stream.behaviorHints ?? {}),
      ...(!isProxied && stream.headers
        ? { proxyHeaders: { request: stream.headers } }
        : {}),
      ...(!isProxied &&
      (stream.format !== 'MP4' || !stream.url.startsWith('https:' ))
        ? { notWebReady: true }
        : {}),
    },
  };
}
