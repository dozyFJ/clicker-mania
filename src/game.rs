//! Clicker Mania economy and persistent bottom navigation.
//! Built as an independent game layer on the WolfCraft Rust engine stack.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tab { Home, Capsules, Upgrades, Settings }

#[derive(Debug, Clone)]
pub struct Game {
    pub coins: f64,
    pub multiplier: u64,
    pub base_income: f64,
    pub upgrades: u32,
    pub tab: Tab,
    pub enemy_hp: u64,
    pub enemy_max_hp: u64,
    pub enemy_level: u32,
    pub hero_level: u32,
    pub hero_xp: u64,
    pub combo: u32,
    pub pets: Vec<String>,
}

impl Default for Game {
    fn default() -> Self {
        Self { coins: 0.0, multiplier: 1, base_income: 1.0, upgrades: 0, tab: Tab::Home, enemy_hp: 100, enemy_max_hp: 100, enemy_level: 1, hero_level: 1, hero_xp: 0, combo: 0, pets: Vec::new() }
    }
}

impl Game {
    pub fn tap(&mut self) {
        self.combo = self.combo.saturating_add(1);
        let damage = (10 + self.upgrades as u64 * 5) * (1 + (self.combo as u64 / 10));
        self.enemy_hp = self.enemy_hp.saturating_sub(damage);
        if self.enemy_hp == 0 {
            self.coins += (self.enemy_level as f64) * 25.0;
            self.hero_xp += 10;
            if self.hero_xp >= self.hero_level as u64 * 50 {
                self.hero_xp = 0;
                self.hero_level += 1;
            }
            self.enemy_level += 1;
            self.enemy_max_hp = 100 + (self.enemy_level as u64 - 1) * 40;
            self.enemy_hp = self.enemy_max_hp;
            self.combo = 0;
        }
    }
    pub fn tick(&mut self, seconds: f64) {
        self.coins += self.base_income * self.multiplier as f64 * seconds.max(0.0);
    }
    pub fn coins_per_second(&self) -> f64 { self.base_income * self.multiplier as f64 }
    pub fn upgrade_price(&self) -> f64 { 50.0 * 2.0_f64.powi((self.upgrades.min(30)) as i32) }
    pub fn upgrade(&mut self) -> bool {
        let cost = self.upgrade_price();
        if self.coins < cost { return false; }
        self.coins -= cost;
        self.upgrades += 1;
        self.base_income += 1.0;
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn multiplier_increases_passive_income() {
        let mut g = Game::default();
        g.tap();
        g.tick(2.0);
        assert_eq!(g.enemy_hp, 90);
        assert_eq!(g.coins, 2.0);
    }
}
