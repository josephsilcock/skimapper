import { renderView } from "./render.js";

const page = document.querySelector("#page");
const response = await fetch(`/api/view${location.search}`);
page.innerHTML = renderView(await response.json());
