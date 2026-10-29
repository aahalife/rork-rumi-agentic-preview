import { img } from './lifeLibrary';

/** Fictional influencer posts, never fetched from Instagram. Nutrients are illustrative estimates. */
export interface SavedRecipe {
  id: string; title: string; author: string; image: string; artwork: string;
  minutes: number; protein: number; fiber: number; calories: number;
  ingredients: string[]; method: string[]; tags: string[]; allergens: string[]; caption: string;
}
export interface MealPreferences { vegetarian: boolean; dairyFree: boolean; glutenFree: boolean; nutFree: boolean; highProtein: boolean; maxMinutes: number }
export const defaultMealPreferences: MealPreferences = { vegetarian: true, dairyFree: false, glutenFree: false, nutFree: false, highProtein: false, maxMinutes: 30 };
export const recipeMedia = { photo: '/img/rumi-chickpea-source-v1.webp', clay: '/img/rumi-chickpea-clay-v1.webp' };
type Seed = [string, string, number, number, string, string[], string[], string[]];
const seeds: Seed[] = [
  ['Chickpea & herb bowl', 'littlelemon.kitchen', 15, 18, 'grain_bowl_chicken_quinoa', ['1 cup cooked chickpeas', '½ cucumber', 'Parsley & mint', '1 tbsp olive oil', '½ lemon'], ['vegan', 'gluten-free'], []],
  ['Crispy tofu & broccoli', 'plantplate.daily', 25, 28, 'grain_bowl_chicken_quinoa', ['Firm tofu', 'Broccoli', 'Rice', 'Tamari'], ['vegan', 'gluten-free'], ['soy']],
  ['Lemon lentil soup', 'littlelemon.kitchen', 30, 21, 'lentil_soup_bowl', ['Red lentils', 'Carrot', 'Lemon', 'Low-sodium stock'], ['vegan', 'gluten-free'], []],
  ['Berry overnight oats', 'slowmornings.table', 10, 14, 'oatmeal_bowl_blueberries', ['Certified gluten-free oats', 'Berries', 'Oat milk', 'Chia seeds'], ['vegan', 'gluten-free'], []],
  ['Greek yogurt crunch', 'slowmornings.table', 5, 24, 'yogurt_parfait_glass', ['Greek yogurt', 'Berries', 'Almonds'], ['vegetarian', 'gluten-free'], ['milk', 'nuts']],
  ['Roasted pepper hummus', 'plantplate.daily', 15, 15, 'grain_bowl_chicken_quinoa', ['Chickpeas', 'Red pepper', 'Tahini', 'Lemon'], ['vegan', 'gluten-free'], ['sesame']],
  ['Spinach egg muffins', 'weeknight.well', 25, 23, 'vegetable_omelette_plate', ['Eggs', 'Spinach', 'Tomatoes'], ['vegetarian', 'gluten-free'], ['egg']],
  ['Black bean taco bowl', 'weeknight.well', 20, 19, 'grain_bowl_chicken_quinoa', ['Black beans', 'Corn', 'Brown rice', 'Avocado'], ['vegan', 'gluten-free'], []],
  ['Miso mushroom rice', 'plantplate.daily', 25, 16, 'grain_bowl_chicken_quinoa', ['Rice', 'Mushrooms', 'Gluten-free miso', 'Tofu'], ['vegan', 'gluten-free'], ['soy']],
  ['Peanut noodle salad', 'weeknight.well', 20, 22, 'grain_bowl_chicken_quinoa', ['Rice noodles', 'Peanuts', 'Cucumber', 'Tofu'], ['vegan', 'gluten-free'], ['nuts', 'soy']],
  ['Lemon salmon plate', 'weeknight.well', 25, 35, 'grilled_salmon_lemon_greens', ['Salmon', 'Lemon', 'Greens', 'Olive oil'], ['gluten-free'], ['fish']],
  ['White bean bruschetta', 'littlelemon.kitchen', 15, 17, 'grain_bowl_chicken_quinoa', ['White beans', 'Wheat sourdough', 'Tomatoes', 'Basil'], ['vegan'], ['wheat']],
  ['Golden cauliflower dal', 'plantplate.daily', 30, 20, 'lentil_soup_bowl', ['Lentils', 'Cauliflower', 'Turmeric', 'Brown rice'], ['vegan', 'gluten-free'], []],
  ['Avocado egg toast', 'slowmornings.table', 10, 19, 'vegetable_omelette_plate', ['Wheat toast', 'Avocado', 'Eggs'], ['vegetarian'], ['wheat', 'egg']],
  ['Strawberry chia pot', 'slowmornings.table', 10, 12, 'yogurt_parfait_glass', ['Chia seeds', 'Strawberries', 'Oat milk'], ['vegan', 'gluten-free'], []],
  ['Quinoa tabbouleh', 'littlelemon.kitchen', 20, 16, 'grain_bowl_chicken_quinoa', ['Quinoa', 'Parsley', 'Tomatoes', 'Lemon'], ['vegan', 'gluten-free'], []],
  ['Sweet potato bean chili', 'weeknight.well', 30, 22, 'lentil_soup_bowl', ['Sweet potato', 'Kidney beans', 'Tomatoes', 'Cumin'], ['vegan', 'gluten-free'], []],
  ['Sesame edamame bowl', 'plantplate.daily', 15, 27, 'grain_bowl_chicken_quinoa', ['Edamame', 'Rice', 'Sesame', 'Carrot'], ['vegan', 'gluten-free'], ['soy', 'sesame']],
  ['Zucchini ricotta pasta', 'weeknight.well', 25, 21, 'grain_bowl_chicken_quinoa', ['Wheat pasta', 'Zucchini', 'Ricotta'], ['vegetarian'], ['wheat', 'milk']],
  ['Coconut chickpea curry', 'plantplate.daily', 25, 18, 'lentil_soup_bowl', ['Chickpeas', 'Coconut milk', 'Spinach', 'Rice'], ['vegan', 'gluten-free'], []],
  ['Apple cinnamon porridge', 'slowmornings.table', 15, 12, 'oatmeal_bowl_blueberries', ['Certified gluten-free oats', 'Apple', 'Cinnamon', 'Oat milk'], ['vegan', 'gluten-free'], []],
  ['Cucumber feta salad', 'littlelemon.kitchen', 10, 15, 'grilled_salmon_lemon_greens', ['Cucumber', 'Feta', 'White beans', 'Dill'], ['vegetarian', 'gluten-free'], ['milk']],
  ['Harissa roasted carrots', 'littlelemon.kitchen', 30, 13, 'grain_bowl_chicken_quinoa', ['Carrots', 'Chickpeas', 'Harissa', 'Lemon'], ['vegan', 'gluten-free'], []],
  ['Tofu breakfast scramble', 'plantplate.daily', 15, 25, 'vegetable_omelette_plate', ['Tofu', 'Spinach', 'Turmeric', 'Pepper'], ['vegan', 'gluten-free'], ['soy']],
  ['Broccoli cheddar soup', 'weeknight.well', 25, 18, 'lentil_soup_bowl', ['Broccoli', 'Cheddar', 'Milk', 'Potato'], ['vegetarian', 'gluten-free'], ['milk']],
  ['Mango yogurt lassi', 'slowmornings.table', 5, 14, 'yogurt_parfait_glass', ['Mango', 'Greek yogurt', 'Cardamom'], ['vegetarian', 'gluten-free'], ['milk']],
  ['Tomato butter bean stew', 'littlelemon.kitchen', 25, 23, 'lentil_soup_bowl', ['Butter beans', 'Tomatoes', 'Garlic', 'Olive oil'], ['vegan', 'gluten-free'], []],
  ['Ginger soba noodles', 'weeknight.well', 20, 18, 'grain_bowl_chicken_quinoa', ['Wheat soba', 'Ginger', 'Tofu', 'Soy sauce'], ['vegan'], ['wheat', 'soy']],
  ['Roasted beet quinoa', 'plantplate.daily', 30, 16, 'grain_bowl_chicken_quinoa', ['Beetroot', 'Quinoa', 'Arugula', 'Lemon'], ['vegan', 'gluten-free'], []],
  ['Banana oat pancakes', 'slowmornings.table', 20, 14, 'oatmeal_bowl_blueberries', ['Certified gluten-free oats', 'Banana', 'Eggs'], ['vegetarian', 'gluten-free'], ['egg']],
  ['Herby potato frittata', 'weeknight.well', 25, 24, 'vegetable_omelette_plate', ['Potatoes', 'Eggs', 'Parsley'], ['vegetarian', 'gluten-free'], ['egg']],
  ['Lime black bean salad', 'littlelemon.kitchen', 10, 20, 'grain_bowl_chicken_quinoa', ['Black beans', 'Corn', 'Lime', 'Cilantro'], ['vegan', 'gluten-free'], []],
  ['Almond berry smoothie', 'slowmornings.table', 5, 13, 'yogurt_parfait_glass', ['Almond milk', 'Berries', 'Almond butter'], ['vegan', 'gluten-free'], ['nuts']],
  ['Baked aubergine lentils', 'plantplate.daily', 35, 22, 'grain_bowl_chicken_quinoa', ['Aubergine', 'Lentils', 'Tomatoes'], ['vegan', 'gluten-free'], []],
  ['Garden minestrone', 'weeknight.well', 30, 16, 'lentil_soup_bowl', ['White beans', 'Wheat pasta', 'Carrots', 'Tomatoes'], ['vegan'], ['wheat']],
  ['Pumpkin seed oat bowl', 'slowmornings.table', 10, 21, 'oatmeal_bowl_blueberries', ['Certified gluten-free oats', 'Pumpkin seeds', 'Oat milk', 'Berries'], ['vegan', 'gluten-free'], []],
];
export const savedRecipes: SavedRecipe[] = seeds.map(([title, author, minutes, protein, artwork, ingredients, tags, allergens], i) => ({
  id: `saved-${i}`, title, author, minutes, protein, fiber: 6 + i % 7, calories: 340 + i % 6 * 35,
  image: i === 0 ? recipeMedia.photo : `/img/rumi-recipe-${i}-v1.webp`, artwork: i === 0 ? recipeMedia.clay : img(artwork) ?? '', ingredients, tags, allergens,
  method: i === 0 ? ['Rinse cooked chickpeas and dice cucumber.', 'Chop herbs; whisk lemon with olive oil.', 'Toss together and portion into two bowls.'] : [`Prepare ${ingredients.slice(0, 2).join(' and ').toLowerCase()}.`, `Cook or assemble with ${ingredients.slice(2).join(' and ').toLowerCase()}.`, 'Portion and season to taste; check ingredient labels.'],
  caption: `${title} for a less rushed day. ${minutes} minutes, ${tags.join(' · ')}. Save this for your next meal! Ingredients and method below.`,
}));
/** Label-based filtering, not a medical/allergy safety certification. */
export function curateRecipes(p: MealPreferences): SavedRecipe[] {
  return savedRecipes.filter(r => (!p.vegetarian || r.tags.includes('vegetarian') || r.tags.includes('vegan')) && (!p.dairyFree || !r.allergens.includes('milk')) && (!p.glutenFree || r.tags.includes('gluten-free')) && (!p.nutFree || !r.allergens.includes('nuts')) && r.minutes <= p.maxMinutes)
    .sort((a, b) => p.highProtein ? b.protein - a.protein : a.minutes - b.minutes);
}
export function recipeInsight(r: SavedRecipe, p: MealPreferences): string {
  return `${r.minutes}-minute preparation fits your ${p.maxMinutes}-minute limit. ${r.protein}g protein and ${r.fiber}g fiber per serving (illustrative estimates). ${p.highProtein ? 'Ranked by protein to match your goal. ' : ''}${p.dairyFree ? 'No milk listed. ' : ''}${p.glutenFree ? 'Post lists gluten-free ingredients. ' : ''}${p.nutFree ? 'No nuts listed. ' : ''}Check labels, cross-contact and portions; post descriptions are not verified nutrition or medical advice.`;
}
export interface ImportedRecipe { recipeId: string; importedAt: number; insight: string }
export interface MealPlanItem { id: string; recipeId: string; day: string; slot: string }
export interface SampleRide { appointmentId: string; pickupAt: number; destination: string; fare: number; status: 'scheduled' | 'driver-late' | 'rebooked' | 'cancelled'; driver: string; plate: string; update: string; checkedAt: number }
export interface ActivityPlanItem { id: string; title: string; minutes: number; image: string; source: string; day: string }
