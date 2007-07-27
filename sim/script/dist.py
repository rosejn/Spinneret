import math

def dist():
	addr_space = int(g.get_property("addr_space"))

	x = int(e.source().get_property("id"))
	y = int(e.target().get_property("id"))

  # true_value if condition else false_value
	d1 = abs(y - x)
	min = y if (y < x) else x
	#min = (y < x ? y : x)
	max = y if (y >= x) else x
	#max = (y >= x ? y : x)
	d2 = (addr_space - max) + min

	dist = d1 if (d1 < d2) else d2

	return dist


def edit_function():
	addr_space = int(g.get_property("addr_space"))
	return int(math.log(addr_space, 2) - math.log(dist(), 2))
