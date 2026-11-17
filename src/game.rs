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
}

impl Default for Game {
    fn default() -> Self {
        Self { coins: 0.0, multiplier: 1, base_income: 1.0, upgrades: 0, tab: Tab::Home }
    }
}

impl Game {
    pub fn tap(&mut self) { self.multiplier = self.multiplier.saturating_add(1); }
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
        assert_eq!(g.multiplier, 2);
        assert_eq!(g.coins, 4.0);
    }
}
