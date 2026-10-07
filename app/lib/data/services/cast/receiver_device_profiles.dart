/// Device profiles for the remote receivers we hand a URL to. Without one the
/// server offers the raw file as direct play, and a receiver that cant demux
/// Matroska or decode HEVC just drops to a black screen.
library;

/// Google's default media receiver. Every Cast device handles H264 in MP4 and
/// VP8/VP9 in WebM, so anything else transcodes to HLS. The empty subtitle
/// list makes the server burn a selected subtitle in, since the receiver is
/// never handed a side-loaded track.
Map<String, dynamic> chromecastDeviceProfile() {
  const bitrate = 20000000;
  return <String, dynamic>{
    'Name': 'Moonfin Chromecast',
    'MaxStaticBitrate': bitrate,
    'MaxStreamingBitrate': bitrate,
    'MusicStreamingTranscodingBitrate': 384000,
    'DirectPlayProfiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'Type': 'Video',
        'Container': 'mp4,m4v',
        'VideoCodec': 'h264',
        'AudioCodec': 'aac,mp3',
      },
      <String, dynamic>{
        'Type': 'Video',
        'Container': 'webm',
        'VideoCodec': 'vp8,vp9',
        'AudioCodec': 'vorbis,opus',
      },
      <String, dynamic>{
        'Type': 'Audio',
        'Container': 'mp3,aac,m4a,m4b,flac,wav,ogg,oga,webma',
        'AudioCodec': 'mp3,aac,flac,wav,vorbis,opus',
      },
    ],
    'TranscodingProfiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'Type': 'Video',
        'Context': 'Streaming',
        'Container': 'ts',
        'Protocol': 'hls',
        'VideoCodec': 'h264',
        'AudioCodec': 'aac,mp3',
        'CopyTimestamps': false,
        'MaxAudioChannels': '2',
      },
      <String, dynamic>{
        'Type': 'Audio',
        'Context': 'Streaming',
        'Container': 'ts',
        'Protocol': 'hls',
        'AudioCodec': 'aac',
        'MaxAudioChannels': '2',
      },
    ],
    'ContainerProfiles': <Map<String, dynamic>>[],
    'CodecProfiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'Type': 'Video',
        'Codec': 'h264',
        'Conditions': <Map<String, dynamic>>[
          <String, dynamic>{
            'Condition': 'EqualsAny',
            'Property': 'VideoProfile',
            'Value': 'high|main|baseline|constrained baseline',
            'IsRequired': false,
          },
          <String, dynamic>{
            'Condition': 'LessThanEqual',
            'Property': 'VideoLevel',
            'Value': '42',
            'IsRequired': false,
          },
          // The oldest Cast devices still in use top out at 1080p, and the
          // sender has no way to ask which model it reached.
          <String, dynamic>{
            'Condition': 'LessThanEqual',
            'Property': 'Width',
            'Value': '1920',
            'IsRequired': false,
          },
        ],
      },
    ],
    'SubtitleProfiles': <Map<String, dynamic>>[],
  };
}

/// AirPlay video, where AVPlayer fetches the URL itself. It handles H264 and
/// HEVC in the MP4 family plus HLS, and nothing Matroska. The 15 Mbps ceiling
/// is the cap this path has always used.
Map<String, dynamic> airPlayDeviceProfile() {
  const bitrate = 15000000;
  return <String, dynamic>{
    'Name': 'Moonfin AirPlay',
    'MaxStaticBitrate': bitrate,
    'MaxStreamingBitrate': bitrate,
    'MusicStreamingTranscodingBitrate': 384000,
    'DirectPlayProfiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'Type': 'Video',
        'Container': 'mp4,m4v,mov',
        'VideoCodec': 'h264,hevc',
        // No FLAC here, since AVFoundation only reads it from its own
        // container and would play an MP4 that carries it silently.
        'AudioCodec': 'aac,mp3,ac3,eac3,alac',
      },
      <String, dynamic>{
        'Type': 'Audio',
        'Container': 'mp3,aac,m4a,m4b,flac,alac,wav',
        'AudioCodec': 'mp3,aac,flac,alac,wav',
      },
    ],
    'TranscodingProfiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'Type': 'Video',
        'Context': 'Streaming',
        'Container': 'ts',
        'Protocol': 'hls',
        'VideoCodec': 'h264',
        'AudioCodec': 'aac,ac3,eac3',
        'CopyTimestamps': false,
      },
      <String, dynamic>{
        'Type': 'Audio',
        'Context': 'Streaming',
        'Container': 'ts',
        'Protocol': 'hls',
        'AudioCodec': 'aac',
      },
    ],
    'ContainerProfiles': <Map<String, dynamic>>[],
    'CodecProfiles': <Map<String, dynamic>>[
      <String, dynamic>{
        'Type': 'Video',
        'Codec': 'h264',
        'Conditions': <Map<String, dynamic>>[
          <String, dynamic>{
            'Condition': 'LessThanEqual',
            'Property': 'VideoLevel',
            'Value': '51',
            'IsRequired': false,
          },
        ],
      },
      <String, dynamic>{
        'Type': 'Video',
        'Codec': 'hevc',
        'Conditions': <Map<String, dynamic>>[
          <String, dynamic>{
            'Condition': 'EqualsAny',
            'Property': 'VideoProfile',
            'Value': 'main|main 10',
            'IsRequired': false,
          },
          <String, dynamic>{
            'Condition': 'LessThanEqual',
            'Property': 'VideoLevel',
            'Value': '153',
            'IsRequired': false,
          },
        ],
      },
    ],
    'SubtitleProfiles': <Map<String, dynamic>>[],
  };
}
