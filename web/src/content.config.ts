import { defineCollection } from "astro:content";
import { file } from "astro/loaders";
import { z } from "zod";

const faq = defineCollection({
  loader: file("src/content/faq.json"),
  schema: z.object({
    question: z.string(),
    answerHtml: z.string(),
  }),
});

export const collections = { faq };
