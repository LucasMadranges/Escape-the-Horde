package utils

import "math"

// CalculateLevel calcule le niveau depuis les points d'experience.
// Formule : level = floor(sqrt(xp / 100)) + 1
func CalculateLevel(xp int) int {
	if xp <= 0 {
		return 1
	}
	return int(math.Sqrt(float64(xp)/100)) + 1
}

// XPForNextLevel retourne l'XP necessaire pour atteindre le niveau suivant.
func XPForNextLevel(currentLevel int) int {
	nextLevel := currentLevel + 1
	return nextLevel * nextLevel * 100
}
