import math
import dist

def edit_function():
	range = [int(g.get_property("min_indg")), int(g.get_property("max_indg"))]

	print v.in_degree(), range[0]
	green = (255.0 / (range[1] - range[0])) * (v.in_degree() - range[0])
	color = "#ff%02x00" % int(green)

	return color
