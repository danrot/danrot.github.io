SITE_FOLDER=site
DIST_FOLDER=dist
URL=https://danielrotter.at

STYLES=${DIST_FOLDER}/style.css
ROBOTS=${DIST_FOLDER}/robots.txt
PAGES=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${addsuffix .html,${basename ${wildcard ${SITE_FOLDER}/*.md}}}}
POSTS=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${addsuffix .html,${basename ${wildcard ${SITE_FOLDER}/*/*/*/*.md}}}}
IMAGES=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${filter ${wildcard ${SITE_FOLDER}/images/*},${wildcard ${SITE_FOLDER}/images/*/}}}
POSTS_IMAGES=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${wildcard ${SITE_FOLDER}/images/posts/*}}
DESCRIPTION=A blog about web development in general and about PHP, JavaScript, Linux and its command line in particular.
INDEX_HTML=dist/index.html
INDEX_MD =dist/index.md
SITEMAP_XML=dist/sitemap.xml
FEED_XML=dist/feed.xml

.PHONY: mkdir
.SUFFIXES:

website: ${STYLES} ${ROBOTS} ${PAGES} ${POSTS} ${IMAGES} ${POSTS_IMAGES} ${INDEX_HTML} dist/sitemap.xml dist/feed.xml

${INDEX_HTML}: ${POSTS} ${PAGES}
	[ ! -f ${INDEX_MD} ] || rm ${INDEX_MD}
	[ ! -f ${INDEX_HTML} ] || rm ${INDEX_HTML}
	echo '## Blog posts' >> ${INDEX_MD}
	for file in $$(echo "${POSTS}" | tr ' ' '\n' | tail -r) ; do \
		date=$$(htmlq 'time[pubdate]' --text --filename $$file) ; \
		title=$$(htmlq 'h1' --text --filename $$file) ; \
		tags=$$(htmlq 'article header div' --text --filename $$file) ; \
		echo "- <time datetime=\"$$date\">$$date</time>: [$$title]($${file#${DIST_FOLDER}}) ($$tags)" >> ${INDEX_MD} ; \
	done
	echo '' >> ${INDEX_MD}
	echo '## Slash pages' >> ${INDEX_MD}
	for file in $$(echo "${PAGES}" | tr ' ' '\n' | tail -r) ; do \
		title=$$(htmlq 'h1' --text --filename $$file) ; \
		excerpt=$$(htmlq 'meta[name="description"]' -a content --text --filename $$file) ; \
		echo "- [$$title]($${file#${DIST_FOLDER}}): $$excerpt" >> ${INDEX_MD} ; \
	done
	pandoc \
		--template templates/master.html \
		--wrap=none \
		-M excerpt='${DESCRIPTION}' \
		-M url=${URL} \
		--output ${INDEX_HTML} \
		${INDEX_MD}
	rm ${INDEX_MD}

${SITEMAP_XML}: ${POSTS} ${PAGES}
	[ ! -f ${SITEMAP_XML} ] || rm ${SITEMAP_XML}
	touch ${SITEMAP_XML}
	echo '<?xml version="1.0" encoding="UTF-8"?>' >> ${SITEMAP_XML}
	echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' >> ${SITEMAP_XML}

	for file in $$(echo "${POSTS}" | tr ' ' '\n') ; do \
		lastmodifieddate=$$(htmlq 'time:not([pubdate])' --text --filename $$file) ; \
		[ -z "$${lastmodifieddate}" ] && lastmodifieddate=$$(htmlq 'time[pubdate]' --text --filename $$file) ; \
		echo '<url>' >> ${SITEMAP_XML} ; \
		echo "<loc>${URL}$${file#${DIST_FOLDER}}</loc>" >> ${SITEMAP_XML} ; \
		echo "<lastmod>$$lastmodifieddate</lastmod>" >> ${SITEMAP_XML} ; \
		echo '</url>' >> ${SITEMAP_XML} ; \
	done

	echo '<url>' >> ${SITEMAP_XML} ; \
	echo "<loc>${URL}$${file#${DIST_FOLDER}}</loc>" >> ${SITEMAP_XML} ; \
	echo '</url>' >> ${SITEMAP_XML} ; \

	for file in $$(echo "${PAGES}" | tr ' ' '\n') ; do \
		echo '<url>' >> ${SITEMAP_XML} ; \
		echo "<loc>${URL}$${file#${DIST_FOLDER}}</loc>" >> ${SITEMAP_XML} ; \
		echo '</url>' >> ${SITEMAP_XML} ; \
	done

	echo '</urlset>' >> ${SITEMAP_XML}

${FEED_XML}: ${POSTS}
	[ ! -f ${FEED_XML} ] || rm ${FEED_XML}
	touch ${FEED_XML}

	echo '<?xml version="1.0" encoding="UTF-8"?>' >> ${FEED_XML}
	echo '<feed xml:lang="en">' >> ${FEED_XML}
	echo '<link href="https://danielrotter.at/feed.xml" rel="self" type="application/atom+xml"/>' >> ${FEED_XML}
	echo '<link href="https://danielrotter.at/" rel="alternate" type="text/html" hreflang="en"/>' >> ${FEED_XML}
	echo "<updated>$$(date +%Y-%m-%d)</updated>" >> ${FEED_XML}
	echo "<id>${URL}/feed.xml</id>" >> ${FEED_XML}
	echo '<title type="html">Daniel Rotter</title>' >> ${FEED_XML}
	echo "<subtitle>${DESCRIPTION}</subtitle>" >> ${FEED_XML}

	for file in $$(echo "${POSTS}" | tr ' ' '\n' | tail -r) ; do \
		url=${URL}/$${file#${DIST_FOLDER}} ; \
		title=$$(htmlq 'h1' --text --filename $$file) ; \
		published=$$(htmlq 'time[pubdate]' --text --filename $$file) ; \
		updated=$$(htmlq 'time:not([pubdate])' --text --filename $$file) ; \
		tags=$$(htmlq 'article header div' --text --filename $$file) ; \
		excerpt=$$(htmlq 'meta[name="description"]' -a content --text --filename $$file) ; \
		[ -z "$${updated}" ] && updated=$$published ; \
		echo '<entry>' >> ${FEED_XML} ; \
		echo "<title type=\"html\">$$title</title>" >> ${FEED_XML} ; \
		echo "<link href=\"$$url\" rel=\"alternate\" type=\"text/html\" title=\"$$title\"/>" >> ${FEED_XML} ; \
		echo "<published>$$published</published>" >> ${FEED_XML} ; \
		echo "<updated>$$updated</updated>" >> ${FEED_XML} ; \
		echo "<id>$$url</id>" >> ${FEED_XML} ; \
		for tag in $$(echo "$$tags" | tr ' ' '\n' | tr -d ',') ; do \
			echo "<category term=\"$$tag\"/>" >> ${FEED_XML} ; \
		done ; \
		echo "<summary type=\"html\">$$excerpt</summary>" >> ${FEED_XML} ; \
		echo '</entry>' >> ${FEED_XML} ; \
	done

	echo '</feed>' >> ${FEED_XML}

${DIST_FOLDER}/%.html: ${SITE_FOLDER}/%.md
	[ -d $(@D) ] || mkdir -p $(@D)
	pandoc \
		--template templates/master.html \
		--wrap=none \
		-M date=${subst /,-,${patsubst %/,%,${patsubst ${DIST_FOLDER}/%,%,${dir $@}}}} \
		-M url=${URL}/${patsubst ${DIST_FOLDER}/%,%,$@} \
		--output $@ $<

${DIST_FOLDER}/%.css: ${SITE_FOLDER}/%.css
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

${DIST_FOLDER}/%.txt: ${SITE_FOLDER}/%.txt
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

${DIST_FOLDER}/images/posts/%: ${SITE_FOLDER}/images/posts/%
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

${DIST_FOLDER}/images/%: ${SITE_FOLDER}/images/%
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

clean:
	rm -r ${DIST_FOLDER}