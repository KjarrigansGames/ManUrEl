require 'elo_rating'
require 'SVG/Graph/Plot'

START_ELO = 1200

Player = Struct.new :name, :elo, :win, :loss, :last_match do
  def to_s
    format "| %-7s | %9s | %-10s | %-11s | ", name, elo, last_match, [win, loss].join('-')
  end

  def elo_history
    @elo_history ||= { 0 => START_ELO }
  end
end

DynamicFactor = {
  5 => 40,
  4 => 35,
  3 => 30,
  2 => 20,
  1 => 10,
}.freeze

def generate_chart(players, filename:)
  graph = SVG::Graph::Plot.new({
    :height => 500,
    :width => 800,
    :key => true,
    :scale_x_integers => true,
    :scale_y_integers => true,
    :graph_title => 'ELO-Score',
    :number_format => "%d",
  })

  players.each do |name, player|
    graph.add_data({
      :data => player.elo_history.to_a.flatten,
      :title => name,
    })
  end

  File.open(filename, 'w') {|f| f.write(graph.burn)}
end

players = {}
match_logs = []

File.readlines('match.log').each.with_index(1) do |match, lfd|
  _, date, p1, p2, score, _ = match.split('|')
  a, b = score.split('-').map(&:to_i)

  pl1 = players[p1.strip] ||= Player.new(p1.strip, START_ELO, 0, 0, nil)
  pl2 = players[p2.strip] ||= Player.new(p2.strip, START_ELO, 0, 0, nil)

  pl1.win += 1 if a > b
  pl1.loss += 1 if a < b
  pl2.win += 1 if b > a
  pl2.loss += 1 if b < a
  pl1.last_match = date.strip
  pl2.last_match = date.strip
  dt = (a - b).abs

  ref = players[p1.strip].elo

  EloRating::k_factor = DynamicFactor[dt]
  match = EloRating::Match.new
  match.add_player(rating: pl1.elo, winner: a > b)
  match.add_player(rating: pl2.elo, winner: b > a)

  pl1.elo, pl2.elo = match.updated_ratings # => [1988, 2012]
  pl1.elo_history[lfd] = pl1.elo
  pl2.elo_history[lfd] = pl2.elo


  dt_elo = (ref - pl1.elo).abs

  match_logs << format("| %3d | %-10s | %-15s | %-15s | %3s | %1d | %4d |", lfd, date, p1, p2, score, dt, dt_elo)
end

generate_chart(players, filename: 'page/elo_changes.svg')

md = File.new('page/README.md', 'w')
md.puts "# Ur-Matches"
md.puts
md.puts "## Participants"
md.puts
md.puts "| Rank | Player  | ELO-Score | Last-Match | Games (w-l) |"
md.puts "| ---- | ------- | --------- | ---------- | ----------- |"
players.sort_by { _2.elo }.reverse_each.with_index(1) do |(_,player),idx|
  md.print '|    ', idx, ' '
  md.puts player
end
md.puts
md.puts "## Elo-Graph"
md.puts
md.puts "![elo-graph](elo_changes.svg)"
md.puts
md.puts "## Match-Log"
md.puts
md.puts "| Idx | Date         | Player 1        | Player 2        | Score | Δ | ΔELO |"
md.puts "| --- | ------------ | --------------- | --------------- | ----- | - | ---- |"
md.puts match_logs.reverse
md.puts
md.puts "## Misc"
md.puts
md.puts "* ELO-Params: NewPlayerScore=1200 K=dynamic[10..40] d=400"
