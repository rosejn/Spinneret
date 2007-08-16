$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'test/unit'

require 'gosim'
require 'spinneret'

class TestGraphExtras < Test::Unit::TestCase

  def setup
    @graph = DirectedAdjacencyGraph.new()
  end

  def teardown
    # nada
  end

  def test_dot_read
    dot_graph = %q{digraph G {
                      addr_space="10000";
                      10 [id="Parent"];
                      10->20;
                      10->30;
                      10->40;
                      20;
                   }}
    @graph.read_from_dot(dot_graph)
    assert_equal(@graph.has_vertex?(10), true)
    assert_equal(@graph.has_vertex?(20), true)
    assert_equal(@graph.has_vertex?(30), true)
    assert_equal(@graph.has_vertex?(40), true)
    assert_equal(@graph.has_vertex?(50), false)

    adj = @graph.adjacent_vertices(10)
    assert_equal(adj.length, 3)
    assert_equal(adj.include?(20), true)
    assert_equal(adj.include?(30), true)
    assert_equal(adj.include?(40), true)
    assert_equal(@graph.adjacent_vertices(30).length, 0)
  end
end

