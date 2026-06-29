/**
 * fuzzy_matcher.js - Advanced fuzzy product matching for voice-to-cart
 * Handles Hinglish → Product Name matching with confidence scoring
 */

// Levenshtein distance (edit distance)
function levenshteinDistance(str1, str2) {
  const len1 = str1.length;
  const len2 = str2.length;
  const matrix = Array(len2 + 1)
    .fill(null)
    .map(() => Array(len1 + 1).fill(0));

  for (let i = 0; i <= len1; i++) matrix[0][i] = i;
  for (let j = 0; j <= len2; j++) matrix[j][0] = j;

  for (let j = 1; j <= len2; j++) {
    for (let i = 1; i <= len1; i++) {
      if (str1[i - 1] === str2[j - 1]) {
        matrix[j][i] = matrix[j - 1][i - 1];
      } else {
        matrix[j][i] = Math.min(
          matrix[j - 1][i - 1] + 1, // substitution
          matrix[j - 1][i] + 1,     // deletion
          matrix[j][i - 1] + 1      // insertion
        );
      }
    }
  }

  return matrix[len2][len1];
}

// Normalize strings for comparison (remove accents, lowercase, trim)
function normalize(str) {
  return str
    .toLowerCase()
    .trim()
    .replace(/[^\w\s]/g, '') // remove special chars
    .replace(/\s+/g, ' ');   // normalize spaces
}

// Calculate similarity score (0-1)
function calculateSimilarity(query, target) {
  const norm1 = normalize(query);
  const norm2 = normalize(target);

  if (norm1 === norm2) return 1.0; // exact match
  if (norm1.includes(norm2) || norm2.includes(norm1)) return 0.95; // substring match

  const distance = levenshteinDistance(norm1, norm2);
  const maxLen = Math.max(norm1.length, norm2.length);
  const similarity = 1 - distance / maxLen;

  return Math.max(0, similarity);
}

// Hinglish transliteration mapping (common patterns)
const hinglishMap = {
  // Common food items
  aata: ['ata', 'maida', 'flour', 'atta'],
  tel: ['oil', 'tel', 'groundnut oil', 'mustard oil', 'ghee'],
  dhal: ['dal', 'pulses', 'lentil', 'arhar', 'moong'],
  chawal: ['rice', 'basmati', 'basmati rice'],
  namak: ['salt', 'table salt'],
  mirch: ['chilli', 'red chilli', 'green chilli', 'pepper'],
  haldi: ['turmeric', 'haldi powder'],
  jeera: ['cumin', 'jeera seed'],
  sabun: ['soap', 'hand soap', 'detergent'],
  tel_sabun: ['soap', 'detergent bar'],
  dudh: ['milk', 'full cream milk', 'toned milk'],
  chhach: ['buttermilk', 'lassi'],
  paneer: ['paneer', 'cottage cheese'],
  ande: ['eggs', 'egg'],
  murga: ['chicken', 'poultry'],
  machli: ['fish', 'salmon', 'tuna'],
  pani: ['water', 'drinking water'],
  chai: ['tea', 'tea powder', 'chai powder'],
  kaafi: ['coffee', 'ground coffee'],
  cheeni: ['sugar', 'white sugar'],
  gud: ['jaggery', 'gur'],
  makhan: ['butter', 'white butter'],
  barfi: ['ghee', 'clarified butter'],
  atta: ['flour', 'wheat flour'],
  besan: ['gram flour', 'besan flour'],
  maida: ['maida', 'all-purpose flour'],
};

/**
 * Find best matching products from catalog
 * @param {string} query - User's voice input (Hinglish)
 * @param {Array} productCatalog - Array of {id, name, price, ...}
 * @param {number} threshold - Minimum similarity score (0-1)
 * @returns {Array} - Sorted matches with confidence scores
 */
function findBestMatches(query, productCatalog, threshold = 0.5) {
  const normalizedQuery = normalize(query);

  // Expand query with Hinglish mappings
  let expandedQueries = [normalizedQuery];
  for (const [hinglish, variants] of Object.entries(hinglishMap)) {
    if (normalizedQuery.includes(normalize(hinglish))) {
      expandedQueries.push(...variants.map(normalize));
    }
  }

  // Score all products against expanded queries
  const matches = productCatalog.map((product) => {
    const productName = normalize(product.name);

    // Get best score across all expanded queries
    const scores = expandedQueries.map((q) =>
      calculateSimilarity(q, productName)
    );
    const maxScore = Math.max(...scores);

    return {
      ...product,
      matchScore: maxScore,
      normalizedQuery,
    };
  });

  // Filter by threshold and sort by score descending
  return matches
    .filter((m) => m.matchScore >= threshold)
    .sort((a, b) => b.matchScore - a.matchScore);
}

/**
 * Resolve ambiguous matches (multiple high-scoring products)
 * Uses: exact substring, frequency, price, and other signals
 */
function resolveAmbiguity(matches, originalQuery, maxResults = 3) {
  if (matches.length <= 1) return matches;

  // Favor exact substring matches
  const exactMatches = matches.filter((m) =>
    normalize(m.name).includes(normalize(originalQuery))
  );

  if (exactMatches.length > 0) {
    return exactMatches.slice(0, maxResults);
  }

  // Otherwise return top scored matches
  return matches.slice(0, maxResults);
}

module.exports = {
  findBestMatches,
  resolveAmbiguity,
  calculateSimilarity,
  normalize,
  hinglishMap,
};
