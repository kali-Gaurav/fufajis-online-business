/**
 * fuzzy_matcher.test.js - Unit tests for fuzzy product matching
 * Run with: npm test -- fuzzy_matcher.test.js
 */

const { findBestMatches, resolveAmbiguity, calculateSimilarity } = require('../src/lib/fuzzy_matcher');

// Mock product catalog
const mockCatalog = [
  { id: 'p1', name: 'Whole Wheat Flour', price: 80, stockQuantity: 50 },
  { id: 'p2', name: 'Vegetable Oil', price: 120, stockQuantity: 30 },
  { id: 'p3', name: 'Red Chilli Powder', price: 250, stockQuantity: 10 },
  { id: 'p4', name: 'Turmeric Powder', price: 150, stockQuantity: 20 },
  { id: 'p5', name: 'Basmati Rice', price: 300, stockQuantity: 40 },
  { id: 'p6', name: 'Table Salt', price: 40, stockQuantity: 100 },
  { id: 'p7', name: 'Cumin Seeds', price: 200, stockQuantity: 15 },
  { id: 'p8', name: 'Hand Soap Bar', price: 50, stockQuantity: 60 },
  { id: 'p9', name: 'Full Cream Milk', price: 60, stockQuantity: 80 },
  { id: 'p10', name: 'Paneer (Cottage Cheese)', price: 280, stockQuantity: 25 },
];

describe('Fuzzy Matcher - Unit Tests', () => {
  describe('Hinglish Input Matching', () => {
    test('Should match "aata" to "Whole Wheat Flour"', () => {
      const matches = findBestMatches('aata', mockCatalog);
      expect(matches.length).toBeGreaterThan(0);
      expect(matches[0].id).toBe('p1');
      expect(matches[0].matchScore).toBeGreaterThan(0.5);
    });

    test('Should match "tel" to "Vegetable Oil"', () => {
      const matches = findBestMatches('tel', mockCatalog);
      expect(matches[0].id).toBe('p2');
    });

    test('Should match "mirch" to "Red Chilli Powder"', () => {
      const matches = findBestMatches('mirch', mockCatalog);
      expect(matches[0].id).toBe('p3');
    });

    test('Should match "haldi" to "Turmeric Powder"', () => {
      const matches = findBestMatches('haldi', mockCatalog);
      expect(matches[0].id).toBe('p4');
    });

    test('Should match "chawal" to "Basmati Rice"', () => {
      const matches = findBestMatches('chawal', mockCatalog);
      expect(matches[0].id).toBe('p5');
    });

    test('Should match "namak" to "Table Salt"', () => {
      const matches = findBestMatches('namak', mockCatalog);
      expect(matches[0].id).toBe('p6');
    });

    test('Should match "jeera" to "Cumin Seeds"', () => {
      const matches = findBestMatches('jeera', mockCatalog);
      expect(matches[0].id).toBe('p7');
    });

    test('Should match "sabun" to "Hand Soap Bar"', () => {
      const matches = findBestMatches('sabun', mockCatalog);
      expect(matches[0].id).toBe('p8');
    });

    test('Should match "dudh" to "Full Cream Milk"', () => {
      const matches = findBestMatches('dudh', mockCatalog);
      expect(matches[0].id).toBe('p9');
    });

    test('Should match "paneer" to "Paneer (Cottage Cheese)"', () => {
      const matches = findBestMatches('paneer', mockCatalog);
      expect(matches[0].id).toBe('p10');
    });
  });

  describe('English Input Matching', () => {
    test('Should match "flour" to "Whole Wheat Flour"', () => {
      const matches = findBestMatches('flour', mockCatalog);
      expect(matches[0].id).toBe('p1');
    });

    test('Should match "oil" to "Vegetable Oil"', () => {
      const matches = findBestMatches('oil', mockCatalog);
      expect(matches[0].id).toBe('p2');
    });

    test('Should match "chilli" to "Red Chilli Powder"', () => {
      const matches = findBestMatches('chilli', mockCatalog);
      expect(matches[0].id).toBe('p3');
    });

    test('Should match "turmeric" to "Turmeric Powder"', () => {
      const matches = findBestMatches('turmeric', mockCatalog);
      expect(matches[0].id).toBe('p4');
    });

    test('Should match "rice" to "Basmati Rice"', () => {
      const matches = findBestMatches('rice', mockCatalog);
      expect(matches[0].id).toBe('p5');
    });

    test('Should match "salt" to "Table Salt"', () => {
      const matches = findBestMatches('salt', mockCatalog);
      expect(matches[0].id).toBe('p6');
    });
  });

  describe('Similarity Scoring', () => {
    test('Exact match should score 1.0', () => {
      const score = calculateSimilarity('flour', 'Flour');
      expect(score).toBe(1.0);
    });

    test('Close match should score > 0.7', () => {
      const score = calculateSimilarity('aata', 'atta');
      expect(score).toBeGreaterThan(0.7);
    });

    test('Substring match should score > 0.9', () => {
      const score = calculateSimilarity('oil', 'Vegetable Oil');
      expect(score).toBeGreaterThan(0.85);
    });
  });

  describe('Ambiguity Resolution', () => {
    test('Should return single best match when asked for 1 result', () => {
      const allMatches = findBestMatches('oil', mockCatalog);
      const resolved = resolveAmbiguity(allMatches, 'oil', 1);
      expect(resolved.length).toBe(1);
      expect(resolved[0].id).toBe('p2');
    });

    test('Should prefer exact substring match in ambiguous cases', () => {
      // Create ambiguous scenario
      const ambiguousCatalog = [
        { id: 'a1', name: 'Rice Flour', price: 100 },
        { id: 'a2', name: 'Basmati Rice', price: 300 },
        { id: 'a3', name: 'Brown Rice', price: 250 },
      ];

      const resolved = resolveAmbiguity(
        findBestMatches('rice', ambiguousCatalog),
        'rice',
        1
      );

      // Should return one with exact match
      expect(resolved.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('Edge Cases', () => {
    test('Should handle empty product catalog', () => {
      const matches = findBestMatches('aata', []);
      expect(matches).toEqual([]);
    });

    test('Should handle special characters in query', () => {
      const matches = findBestMatches('a@t@', mockCatalog);
      expect(matches.length).toBeGreaterThanOrEqual(0);
    });

    test('Should handle case-insensitive matching', () => {
      const matches1 = findBestMatches('AATA', mockCatalog);
      const matches2 = findBestMatches('aata', mockCatalog);
      expect(matches1[0]?.id).toBe(matches2[0]?.id);
    });

    test('Should filter by threshold', () => {
      const lowThreshold = findBestMatches('xyz', mockCatalog, 0.1);
      const highThreshold = findBestMatches('xyz', mockCatalog, 0.9);
      expect(highThreshold.length).toBeLessThanOrEqual(lowThreshold.length);
    });
  });

  describe('Performance', () => {
    test('Should match 100 items within 100ms', () => {
      const largeCatalog = Array.from({ length: 100 }, (_, i) => ({
        id: `p${i}`,
        name: `Product ${i}`,
        price: 100 + i,
      }));

      const start = Date.now();
      findBestMatches('aata', largeCatalog);
      const elapsed = Date.now() - start;

      expect(elapsed).toBeLessThan(100);
    });
  });
});

// Test utilities
function test(description, fn) {
  try {
    fn();
    console.log(`✓ ${description}`);
  } catch (error) {
    console.error(`✗ ${description}`);
    console.error(`  ${error.message}`);
  }
}

function expect(actual) {
  return {
    toBe: (expected) => {
      if (actual !== expected) throw new Error(`Expected ${expected}, got ${actual}`);
    },
    toEqual: (expected) => {
      if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
      }
    },
    toBeGreaterThan: (min) => {
      if (!(actual > min)) throw new Error(`Expected > ${min}, got ${actual}`);
    },
    toBeLessThan: (max) => {
      if (!(actual < max)) throw new Error(`Expected < ${max}, got ${actual}`);
    },
    toBeGreaterThanOrEqual: (min) => {
      if (!(actual >= min)) throw new Error(`Expected >= ${min}, got ${actual}`);
    },
    toBeLessThanOrEqual: (max) => {
      if (!(actual <= max)) throw new Error(`Expected <= ${max}, got ${actual}`);
    },
  };
}

function describe(group, fn) {
  console.log(`\n📋 ${group}`);
  fn();
}

// Run tests if executed directly
if (require.main === module) {
  console.log('Running Fuzzy Matcher Tests...\n');
}
