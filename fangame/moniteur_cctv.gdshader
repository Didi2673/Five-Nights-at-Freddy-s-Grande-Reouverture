shader_type canvas_item;

// --- PARAMÈTRES RÉGLABLES DANS L'INSPECTEUR ---
uniform float quantite_bruit : hint_range(0.0, 1.0) = 0.9; // Opacité du bruit (0 à 1)
uniform float densite : hint_range(0.0, 10.0) = 1; // Finesse du grain

// Fonction mathématique pour générer du hasard
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // On récupère la couleur de base de l'écran (optionnel, ici on veut juste du bruit)
    vec4 couleur_ecran = texture(TEXTURE, UV);
    
    // On crée le bruit en utilisant le TEMPS (TIME) pour que ça bouge
    float bruit = random(UV * densite + vec2(TIME * 10.0, TIME * 50.0));
    
    // On définit la couleur finale : Blanc avec transparence
    // vec4(Rouge, Vert, Bleu, Alpha)
    COLOR = vec4(1, 1, 1, bruit * quantite_bruit * 1.3);
}