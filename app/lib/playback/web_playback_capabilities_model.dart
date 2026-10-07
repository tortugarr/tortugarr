class WebPlaybackCapabilities {
  const WebPlaybackCapabilities({
    required this.supportsAvc,
    required this.supportsAvcHigh10,
    required this.avcMainLevel,
    required this.avcHigh10Level,
    required this.supportsHevc,
    required this.supportsHevcMain10,
    required this.hevcMainLevel,
    required this.supportsHevcDolbyVision,
    required this.supportsHevcDolbyVisionEl,
    required this.supportsHevcHdr10,
    required this.supportsHevcHdr10Plus,
    required this.supportsAv1,
    required this.supportsAv1Main10,
    required this.supportsAv1DolbyVision,
    required this.supportsAv1Hdr10,
    required this.supportsAv1Hdr10Plus,
    required this.supportsVc1,
    required this.maxResolutionAvcWidth,
    required this.maxResolutionAvcHeight,
    required this.maxResolutionHevcWidth,
    required this.maxResolutionHevcHeight,
    required this.maxResolutionAv1Width,
    required this.maxResolutionAv1Height,
    required this.maxResolutionVc1Width,
    required this.maxResolutionVc1Height,
    required this.supportsDvProfile5,
    required this.supportsDvProfile7,
    required this.supportsDvProfile8,
    required this.knownHevcDoviHdr10PlusBug,
    required this.canDecodeAc3,
    required this.canDecodeEac3,
    required this.canDecodeDts,
    required this.canDecodeDtsHd,
    required this.canDecodeTrueHd,
    required this.canDecodeFlac,
    required this.maxPcmChannels,
    required this.supportsVp8,
    required this.supportsVp9,
    required this.canPlayMkv,
    required this.canPlayHls,
    required this.canPlayNativeHls,
    required this.canPlayNativeHlsInFmp4,
    required this.canDecodeAc3InHls,
    required this.canDecodeMp3InHls,
    required this.canDecodeOpus,
    required this.canDecodeAlac,
    required this.isSafari,
    required this.isFirefox,
    required this.isChrome,
    required this.isEdgeChromium,
    required this.isWindows,
    required this.isMacOS,
    required this.isIOS,
    required this.iOSMajorVersion,
    required this.isAndroid,
    required this.isMobile,
    required this.browserMajorVersion,
    required this.maxStreamingBitrate,
  });

  final bool supportsAvc;
  final bool supportsAvcHigh10;
  final int avcMainLevel;
  final int avcHigh10Level;
  final bool supportsHevc;
  final bool supportsHevcMain10;
  final int hevcMainLevel;
  final bool supportsHevcDolbyVision;
  final bool supportsHevcDolbyVisionEl;
  final bool supportsHevcHdr10;
  final bool supportsHevcHdr10Plus;
  final bool supportsAv1;
  final bool supportsAv1Main10;
  final bool supportsAv1DolbyVision;
  final bool supportsAv1Hdr10;
  final bool supportsAv1Hdr10Plus;
  final bool supportsVc1;
  final int maxResolutionAvcWidth;
  final int maxResolutionAvcHeight;
  final int maxResolutionHevcWidth;
  final int maxResolutionHevcHeight;
  final int maxResolutionAv1Width;
  final int maxResolutionAv1Height;
  final int maxResolutionVc1Width;
  final int maxResolutionVc1Height;
  final bool supportsDvProfile5;
  final bool supportsDvProfile7;
  final bool supportsDvProfile8;
  final bool knownHevcDoviHdr10PlusBug;
  final bool canDecodeAc3;
  final bool canDecodeEac3;
  final bool canDecodeDts;
  final bool canDecodeDtsHd;
  final bool canDecodeTrueHd;
  final bool canDecodeFlac;
  final int maxPcmChannels;
  final bool supportsVp8;
  final bool supportsVp9;
  final bool canPlayMkv;
  final bool canPlayHls;
  final bool canPlayNativeHls;
  final bool canPlayNativeHlsInFmp4;
  final bool canDecodeAc3InHls;
  final bool canDecodeMp3InHls;
  final bool canDecodeOpus;
  final bool canDecodeAlac;
  final bool isSafari;
  final bool isFirefox;
  final bool isChrome;
  final bool isEdgeChromium;
  final bool isWindows;
  final bool isMacOS;
  final bool isIOS;
  final int iOSMajorVersion;
  final bool isAndroid;
  final bool isMobile;
  final int browserMajorVersion;
  final int maxStreamingBitrate;

  static const WebPlaybackCapabilities conservative = WebPlaybackCapabilities(
    supportsAvc: false,
    supportsAvcHigh10: false,
    avcMainLevel: 0,
    avcHigh10Level: 0,
    supportsHevc: false,
    supportsHevcMain10: false,
    hevcMainLevel: 0,
    supportsHevcDolbyVision: false,
    supportsHevcDolbyVisionEl: false,
    supportsHevcHdr10: false,
    supportsHevcHdr10Plus: false,
    supportsAv1: false,
    supportsAv1Main10: false,
    supportsAv1DolbyVision: false,
    supportsAv1Hdr10: false,
    supportsAv1Hdr10Plus: false,
    supportsVc1: false,
    maxResolutionAvcWidth: 0,
    maxResolutionAvcHeight: 0,
    maxResolutionHevcWidth: 0,
    maxResolutionHevcHeight: 0,
    maxResolutionAv1Width: 0,
    maxResolutionAv1Height: 0,
    maxResolutionVc1Width: 0,
    maxResolutionVc1Height: 0,
    supportsDvProfile5: false,
    supportsDvProfile7: false,
    supportsDvProfile8: false,
    knownHevcDoviHdr10PlusBug: false,
    canDecodeAc3: false,
    canDecodeEac3: false,
    canDecodeDts: false,
    canDecodeDtsHd: false,
    canDecodeTrueHd: false,
    canDecodeFlac: false,
    maxPcmChannels: 2,
    supportsVp8: false,
    supportsVp9: false,
    canPlayMkv: false,
    canPlayHls: false,
    canPlayNativeHls: false,
    canPlayNativeHlsInFmp4: false,
    canDecodeAc3InHls: false,
    canDecodeMp3InHls: false,
    canDecodeOpus: false,
    canDecodeAlac: false,
    isSafari: false,
    isFirefox: false,
    isChrome: false,
    isEdgeChromium: false,
    isWindows: false,
    isMacOS: false,
    isIOS: false,
    iOSMajorVersion: 0,
    isAndroid: false,
    isMobile: false,
    browserMajorVersion: 0,
    maxStreamingBitrate: 120000000,
  );
}
