shader_type spatial;

uniform float skew_amount = 0.05; // Adjust this value to control the skew intensity

void vertex() {
	VERTEX.x += VERTEX.y * skew_amount + VERTEX.z * skew_amount;
	VERTEX.y += VERTEX.x * skew_amount + VERTEX.z * skew_amount;
	VERTEX.z += VERTEX.x * skew_amount + VERTEX.y * skew_amount;
}
