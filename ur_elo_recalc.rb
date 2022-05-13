require 'elo_rating'

Player = Struct.new :name, :elo, :win, :loss, :last_match do
  def to_s
    format "| %-7s | %9s | %-10s | %-11s | ", name, elo, last_match, [win, loss].join('-')
  end
end

players = {}
match_logs = []

File.readlines('match.log').each do |match|
  _, date, p1, p2, score, _ = match.split('|')
  a, b = score.split('-').map(&:to_i)

  pl1 = players[p1.strip] ||= Player.new(p1.strip, 1200, 0, 0, nil)
  pl2 = players[p2.strip] ||= Player.new(p2.strip, 1200, 0, 0, nil)

  pl1.win += 1 if a > b
  pl1.loss += 1 if a < b
  pl2.win += 1 if b > a
  pl2.loss += 1 if b < a
  pl1.last_match = date.strip
  pl2.last_match = date.strip

  ref = players[p1.strip].elo

  match = EloRating::Match.new
  match.add_player(rating: pl1.elo, winner: a > b)
  match.add_player(rating: pl2.elo, winner: b > a)

  pl1.elo, pl2.elo = match.updated_ratings # => [1988, 2012]
  dt = (a - b).abs
  dt_elo = (ref - pl1.elo).abs

  match_logs << format("| %-10s | %-15s | %-15s | %3s | %1d | %4d |", date, p1, p2, score, dt, dt_elo)
end

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
md.puts
md.puts "## Match-Log"
md.puts
md.puts "| Date         | Player 1        | Player 2        | Score | Δ | ΔELO |"
md.puts "| ------------ | --------------- | --------------- | ----- | - | ---- |"
md.puts match_logs
md.puts
md.puts "## Misc"
md.puts
md.puts "* ELO-Params: K=24 d=400"
