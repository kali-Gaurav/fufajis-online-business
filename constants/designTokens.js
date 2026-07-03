/**
 * FUFAJI STORE — Design System Tokens
 * Date: 2026-07-02
 * Status: PRODUCTION
 */

export const designTokens = {
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  },

  typography: {
    h1: { fontSize: 28, fontWeight: '700', lineHeight: 36 },
    h2: { fontSize: 20, fontWeight: '700', lineHeight: 28 },
    h3: { fontSize: 16, fontWeight: '600', lineHeight: 24 },
    body: { fontSize: 14, fontWeight: '400', lineHeight: 20 },
    caption: { fontSize: 12, fontWeight: '400', lineHeight: 16 },
    label: { fontSize: 12, fontWeight: '600', lineHeight: 16 },
  },

  colors: {
    primary: '#1A5276',
    primaryLight: '#2E7BA8',
    primaryDark: '#0D3B57',
    accent: '#E67E22',
    accentLight: '#F39C12',
    accentDark: '#D35400',
    success: '#27AE60',
    error: '#E74C3C',
    background: '#FDFEFE',
    surface: '#FFFFFF',
    surface2: '#F5F6FA',
    border: '#ECF0F1',
    text: {
      primary: '#1C2833',
      secondary: '#566573',
      tertiary: '#95A5A6',
      disabled: '#BDC3C7',
      inverse: '#FFFFFF',
    },
  },

  sizing: {
    productImage: 140,
    productThumbnail: 80,
    bannerHeight: 200,
    bottomNav: 64,
    topNav: 56,
    buttonHeight: 48,
    buttonHeightSmall: 36,
  },

  radius: {
    sm: 4,
    md: 8,
    lg: 12,
    xl: 16,
    full: 24,
  },

  shadows: {
    sm: '0px 1px 2px rgba(0, 0, 0, 0.05)',
    md: '0px 2px 4px rgba(0, 0, 0, 0.1)',
    lg: '0px 4px 8px rgba(0, 0, 0, 0.15)',
  },

  zIndex: {
    base: 0,
    dropdown: 100,
    modal: 400,
    tooltip: 600,
  },
};

export default designTokens;
